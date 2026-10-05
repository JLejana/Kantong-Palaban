import { randomUUID } from "node:crypto";
import type { ConnectedClient } from "../networking/client.js";
import { send } from "../networking/client.js";
import type { ClientMessage, LobbyPlayer } from "../types/protocol.js";

type Lobby = { id: string; players: Map<string, boolean> };
type ResultMessage = Extract<ClientMessage, { type: "match_result" }>;
type MatchRoom = {
  id: string;
  players: [string, string];
  submittedResults: Map<string, ResultMessage>;
  startedAt: number;
};

export type CompletedMatch = {
  matchId: string;
  playerIds: [string, string];
  winnerId: string;
  playerOneRounds: number;
  playerTwoRounds: number;
  durationSeconds: number;
};

export type ResultStatus =
  | { status: "rejected"; reason: string }
  | { status: "pending" }
  | { status: "complete"; match: CompletedMatch };

export class RoomManager {
  private readonly lobbies = new Map<string, Lobby>();
  private readonly matches = new Map<string, MatchRoom>();

  createLobby(client: ConnectedClient): void {
    this.leaveLobby(client);
    const lobby: Lobby = { id: randomUUID(), players: new Map([[client.id, false]]) };
    this.lobbies.set(lobby.id, lobby);
    client.lobbyId = lobby.id;
    send(client, { type: "lobby_created", lobbyId: lobby.id });
    this.broadcastLobby(lobby);
  }

  joinLobby(client: ConnectedClient, lobbyId: string): boolean {
    const lobby = this.lobbies.get(lobbyId);
    if (!lobby || lobby.players.size >= 2) return false;
    this.leaveLobby(client);
    lobby.players.set(client.id, false);
    client.lobbyId = lobby.id;
    this.broadcastLobby(lobby);
    return true;
  }

  setReady(client: ConnectedClient, ready: boolean): void {
    const lobby = client.lobbyId ? this.lobbies.get(client.lobbyId) : undefined;
    if (!lobby?.players.has(client.id)) return;
    lobby.players.set(client.id, ready);
    this.broadcastLobby(lobby);
    if (lobby.players.size === 2 && [...lobby.players.values()].every(Boolean)) {
      const players = [...lobby.players.keys()] as [string, string];
      this.createMatch(players);
      this.lobbies.delete(lobby.id);
    }
  }

  createMatch(playerIds: [string, string]): string {
    const id = randomUUID();
    this.matches.set(id, { id, players: playerIds, submittedResults: new Map(), startedAt: Date.now() });
    playerIds.forEach((playerId, index) => {
      const client = clients.get(playerId);
      if (client) {
        client.matchId = id;
        client.lastInputFrame = -1;
        delete client.lobbyId;
        send(client, { type: "match_found", matchId: id, players: [...playerIds], playerSlot: index + 1, startFrame: 0 });
      }
    });
    return id;
  }

  relayInput(sender: ConnectedClient, message: Extract<ClientMessage, { type: "input" }>): boolean {
    const room = this.matches.get(message.matchId);
    if (!room || sender.matchId !== room.id || message.playerId !== sender.id || !room.players.includes(sender.id)) return false;
    if (message.frame <= sender.lastInputFrame || message.frame > sender.lastInputFrame + 600) return false;
    sender.lastInputFrame = message.frame;
    for (const playerId of room.players) {
      if (playerId !== sender.id) {
        const peer = clients.get(playerId);
        if (peer) send(peer, message);
      }
    }
    return true;
  }

  relaySignal(sender: ConnectedClient, message: Extract<ClientMessage, { type: "webrtc_signal" }>): boolean {
    const room = this.matches.get(message.matchId);
    if (!room || !room.players.includes(sender.id) || !room.players.includes(message.targetPlayerId) || sender.id === message.targetPlayerId) return false;
    const target = clients.get(message.targetPlayerId);
    if (!target) return false;
    send(target, { type: "webrtc_signal", matchId: room.id, fromPlayerId: sender.id, signal: message.signal });
    return true;
  }

  submitResult(client: ConnectedClient, result: ResultMessage): ResultStatus {
    const room = this.matches.get(result.matchId);
    if (!room || !room.players.includes(client.id)) return { status: "rejected", reason: "Player is not in this match" };
    if (!room.players.includes(result.winnerId)) return { status: "rejected", reason: "Winner is not in this match" };
    const validScore =
      result.playerOneRounds >= 0 && result.playerOneRounds <= 2 &&
      result.playerTwoRounds >= 0 && result.playerTwoRounds <= 2 &&
      Math.max(result.playerOneRounds, result.playerTwoRounds) === 2 &&
      result.playerOneRounds !== result.playerTwoRounds;
    const expectedWinner = result.playerOneRounds > result.playerTwoRounds ? room.players[0] : room.players[1];
    if (!validScore || result.winnerId !== expectedWinner || result.durationSeconds < 1 || result.durationSeconds > 1800) {
      return { status: "rejected", reason: "Result values are outside match limits" };
    }
    room.submittedResults.set(client.id, result);
    if (room.submittedResults.size < room.players.length) return { status: "pending" };
    const reports = [...room.submittedResults.values()];
    const first = reports[0];
    const second = reports[1];
    if (!first || !second || first.winnerId !== second.winnerId || first.playerOneRounds !== second.playerOneRounds || first.playerTwoRounds !== second.playerTwoRounds) {
      room.submittedResults.clear();
      return { status: "rejected", reason: "Players submitted conflicting match results" };
    }
    this.matches.delete(room.id);
    for (const playerId of room.players) {
      const player = clients.get(playerId);
      if (player) delete player.matchId;
    }
    return {
      status: "complete",
      match: {
        matchId: room.id,
        playerIds: room.players,
        winnerId: first.winnerId,
        playerOneRounds: first.playerOneRounds,
        playerTwoRounds: first.playerTwoRounds,
        durationSeconds: Math.round((first.durationSeconds + second.durationSeconds) / 2),
      },
    };
  }

  leaveMatch(client: ConnectedClient, matchId: string): boolean {
    const room = this.matches.get(matchId);
    if (!room?.players.includes(client.id)) return false;
    this.endMatchForDisconnect(room, client.id);
    return true;
  }

  markDisconnected(client: ConnectedClient): void {
    if (!client.matchId) return;
    const room = this.matches.get(client.matchId);
    if (!room) return;
    for (const playerId of room.players) {
      if (playerId !== client.id) {
        const peer = clients.get(playerId);
        if (peer) send(peer, { type: "peer_disconnected", playerId: client.id });
      }
    }
  }

  markReconnected(client: ConnectedClient): void {
    if (!client.matchId) return;
    const room = this.matches.get(client.matchId);
    if (!room) return;
    for (const playerId of room.players) {
      if (playerId !== client.id) {
        const peer = clients.get(playerId);
        if (peer) send(peer, { type: "peer_reconnected", playerId: client.id });
      }
    }
  }

  disconnect(client: ConnectedClient): void {
    this.leaveLobby(client);
    if (!client.matchId) return;
    const room = this.matches.get(client.matchId);
    if (room) this.endMatchForDisconnect(room, client.id);
  }

  private endMatchForDisconnect(room: MatchRoom, disconnectedId: string): void {
    this.matches.delete(room.id);
    for (const playerId of room.players) {
      const player = clients.get(playerId);
      if (player) delete player.matchId;
      if (playerId !== disconnectedId && player) send(player, { type: "peer_disconnected", playerId: disconnectedId });
    }
  }

  private leaveLobby(client: ConnectedClient): void {
    if (!client.lobbyId) return;
    const lobby = this.lobbies.get(client.lobbyId);
    lobby?.players.delete(client.id);
    if (lobby?.players.size === 0) this.lobbies.delete(lobby.id);
    else if (lobby) this.broadcastLobby(lobby);
    delete client.lobbyId;
  }

  private broadcastLobby(lobby: Lobby): void {
    const players: LobbyPlayer[] = [...lobby.players].map(([id, ready]) => ({ id, ready }));
    for (const playerId of lobby.players.keys()) {
      const client = clients.get(playerId);
      if (client) send(client, { type: "lobby_state", lobbyId: lobby.id, players });
    }
  }
}

export const clients = new Map<string, ConnectedClient>();

