import { randomUUID } from "node:crypto";
import { WebSocketServer, type RawData, type VerifyClientCallbackSync, type WebSocket } from "ws";
import { config } from "./config/env.js";
import { MatchmakingQueue } from "./matchmaking/queue.js";
import { send, type ConnectedClient } from "./networking/client.js";
import { clients, RoomManager, type CompletedMatch } from "./rooms/room-manager.js";
import { verifyAccessToken } from "./supabase/auth.js";
import { persistMatchResult } from "./supabase/match-results.js";
import { parseClientMessage } from "./validation/messages.js";
import type { ClientMessage } from "./types/protocol.js";

type ResumeSession = { client: ConnectedClient; expiresAt: number };

const queue = new MatchmakingQueue();
const rooms = new RoomManager();
const resumeSessions = new Map<string, ResumeSession>();
const metrics = { connections: 0, messages: 0, rejected: 0, matches: 0 };
const verifyClient: VerifyClientCallbackSync = ({ origin }) =>
  !origin || config.allowedOrigins.size === 0 || config.allowedOrigins.has(origin);

const server = new WebSocketServer({
  host: config.host,
  port: config.port,
  verifyClient,
  maxPayload: 16 * 1024,
  perMessageDeflate: false,
});

server.on("connection", (socket) => {
  let client = createClient(socket);
  clients.set(client.id, client);
  metrics.connections += 1;
  send(client, { type: "welcome", connectionId: client.id });

  socket.on("message", (data: RawData) => {
    metrics.messages += 1;
    if (!withinRateLimit(client)) {
      metrics.rejected += 1;
      socket.close(1008, "Rate limit exceeded");
      return;
    }
    const message = parseClientMessage(data.toString());
    if (!message) {
      metrics.rejected += 1;
      send(client, { type: "error", code: "invalid_message", message: "Message did not match the protocol" });
      return;
    }
    void handleMessage(client, message, socket).then((resolvedClient) => {
      client = resolvedClient;
    }).catch((error: unknown) => {
      console.error("Message handler failed", error);
      send(client, { type: "error", code: "server_error", message: "The server could not process the request" });
    });
  });

  socket.on("close", () => disconnectClient(client, socket));
  socket.on("error", (error) => console.warn("WebSocket client error", { playerId: client.id, error: error.message }));
});

async function handleMessage(client: ConnectedClient, message: ClientMessage, socket: WebSocket): Promise<ConnectedClient> {
  if (message.type === "authenticate") return authenticateClient(client, message.accessToken, message.resumeToken, socket);
  if (message.type === "ping") {
    send(client, { type: "pong", sentAt: message.sentAt, serverAt: Date.now() });
    return client;
  }
  if (!client.authenticated) {
    metrics.rejected += 1;
    send(client, { type: "error", code: "not_authenticated", message: "Authenticate before using matchmaking" });
    return client;
  }

  switch (message.type) {
    case "lobby_create": rooms.createLobby(client); break;
    case "lobby_join":
      if (!rooms.joinLobby(client, message.lobbyId)) send(client, { type: "error", code: "lobby_unavailable", message: "Lobby not found or full" });
      break;
    case "ready": rooms.setReady(client, message.ready); break;
    case "queue_join":
      queue.join(client.id);
      send(client, { type: "queue_joined" });
      matchQueuedPlayers();
      break;
    case "queue_leave":
      queue.leave(client.id);
      send(client, { type: "queue_left" });
      break;
    case "match_leave":
      if (!rooms.leaveMatch(client, message.matchId)) send(client, { type: "error", code: "invalid_match", message: "Match leave rejected" });
      break;
    case "webrtc_signal":
      if (!rooms.relaySignal(client, message)) send(client, { type: "error", code: "invalid_signal", message: "WebRTC signal rejected" });
      break;
    case "input":
      if (!rooms.relayInput(client, message)) {
        metrics.rejected += 1;
        send(client, { type: "error", code: "invalid_input", message: "Input rejected" });
      }
      break;
    case "match_result": {
      const result = rooms.submitResult(client, message);
      if (result.status === "rejected") {
        metrics.rejected += 1;
        send(client, { type: "error", code: "invalid_result", message: result.reason });
      } else if (result.status === "pending") {
        send(client, { type: "match_result_accepted", matchId: message.matchId });
      } else {
        await completeMatch(result.match);
      }
      break;
    }
  }
  return client;
}

async function authenticateClient(
  transient: ConnectedClient,
  accessToken: string,
  resumeToken: string,
  socket: WebSocket,
): Promise<ConnectedClient> {
  const resumable = resumeToken ? resumeSessions.get(resumeToken) : undefined;
  if (resumable && resumable.expiresAt > Date.now() && !resumable.client.connected) {
    const restored = resumable.client;
    clients.delete(transient.id);
    resumeSessions.delete(resumeToken);
    restored.socket = socket;
    restored.connected = true;
    restored.rateWindowStartedAt = Date.now();
    restored.rateMessageCount = 0;
    rotateResumeToken(restored);
    rooms.markReconnected(restored);
    send(restored, {
      type: "authenticated", playerId: restored.id, userId: restored.userId ?? "", guest: restored.guest,
      resumeToken: restored.resumeToken ?? "", resumed: true,
    });
    return restored;
  }

  const user = accessToken ? await verifyAccessToken(accessToken) : null;
  if (accessToken && !user) {
    send(transient, { type: "error", code: "invalid_token", message: "Supabase access token was rejected" });
    socket.close(1008, "Invalid access token");
    return transient;
  }
  if (!user && config.requireAuth) {
    send(transient, { type: "error", code: "auth_required", message: "This server requires a Supabase account" });
    socket.close(1008, "Authentication required");
    return transient;
  }

  transient.authenticated = true;
  transient.guest = user === null;
  if (user) transient.userId = user.id;
  rotateResumeToken(transient);
  send(transient, {
    type: "authenticated", playerId: transient.id, userId: transient.userId ?? "", guest: transient.guest,
    resumeToken: transient.resumeToken ?? "", resumed: false,
  });
  return transient;
}

async function completeMatch(match: CompletedMatch): Promise<void> {
  metrics.matches += 1;
  for (const playerId of match.playerIds) {
    const player = clients.get(playerId);
    if (player) send(player, { type: "match_result_accepted", matchId: match.matchId });
  }
  const first = clients.get(match.playerIds[0]);
  const second = clients.get(match.playerIds[1]);
  const winner = clients.get(match.winnerId);
  if (!first?.userId || !second?.userId || !winner?.userId) return;
  await persistMatchResult({
    matchId: match.matchId,
    playerOneId: first.userId,
    playerTwoId: second.userId,
    winnerId: winner.userId,
    playerOneRounds: match.playerOneRounds,
    playerTwoRounds: match.playerTwoRounds,
    durationSeconds: match.durationSeconds,
  });
}

function createClient(socket: WebSocket): ConnectedClient {
  return {
    id: randomUUID(), socket, connected: true, authenticated: false, guest: true,
    lastInputFrame: -1, rateWindowStartedAt: Date.now(), rateMessageCount: 0,
  };
}

function rotateResumeToken(client: ConnectedClient): void {
  if (client.resumeToken) resumeSessions.delete(client.resumeToken);
  client.resumeToken = randomUUID();
  resumeSessions.set(client.resumeToken, { client, expiresAt: Number.POSITIVE_INFINITY });
}

function disconnectClient(client: ConnectedClient, socket: WebSocket): void {
  if (client.socket !== socket || !client.connected) return;
  client.connected = false;
  queue.leave(client.id);
  rooms.markDisconnected(client);
  if (!client.authenticated || !client.resumeToken) {
    rooms.disconnect(client);
    clients.delete(client.id);
    return;
  }
  const token = client.resumeToken;
  const expiresAt = Date.now() + config.reconnectWindowMs;
  resumeSessions.set(token, { client, expiresAt });
  setTimeout(() => {
    const session = resumeSessions.get(token);
    if (!client.connected && session?.client === client && session.expiresAt <= Date.now()) {
      rooms.disconnect(client);
      clients.delete(client.id);
      resumeSessions.delete(token);
    }
  }, config.reconnectWindowMs + 25).unref();
}

function withinRateLimit(client: ConnectedClient): boolean {
  const now = Date.now();
  if (now - client.rateWindowStartedAt >= 1000) {
    client.rateWindowStartedAt = now;
    client.rateMessageCount = 0;
  }
  client.rateMessageCount += 1;
  return client.rateMessageCount <= config.messagesPerSecond;
}

function matchQueuedPlayers(): void {
  let pair = queue.takePair();
  while (pair) {
    rooms.createMatch(pair);
    pair = queue.takePair();
  }
}

setInterval(() => console.log("server_metrics", { ...metrics, activeClients: clients.size }), 60_000).unref();
server.on("listening", () => console.log(`Fighter server listening on ws://${config.host}:${config.port}`));
server.on("error", (error) => console.error("WebSocket server error", error));

