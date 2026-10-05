import type WebSocket from "ws";
import type { ServerMessage } from "../types/protocol.js";

export type ConnectedClient = {
  id: string;
  socket: WebSocket;
  connected: boolean;
  authenticated: boolean;
  guest: boolean;
  userId?: string;
  resumeToken?: string;
  lobbyId?: string;
  matchId?: string;
  lastInputFrame: number;
  rateWindowStartedAt: number;
  rateMessageCount: number;
};

export function send(client: ConnectedClient, message: ServerMessage): void {
  if (client.connected && client.socket.readyState === client.socket.OPEN) {
    client.socket.send(JSON.stringify(message));
  }
}

