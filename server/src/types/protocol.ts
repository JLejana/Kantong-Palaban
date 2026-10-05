export type CombatInput = {
  left: boolean;
  right: boolean;
  jump: boolean;
  crouch: boolean;
  lp: boolean;
  rp: boolean;
  lk: boolean;
  rk: boolean;
  block: boolean;
};

export type WebRTCSignal =
  | { kind: "offer" | "answer"; sdp: string }
  | { kind: "ice"; mid: string; index: number; candidate: string };

export type ClientMessage =
  | { type: "authenticate"; accessToken: string; resumeToken: string }
  | { type: "lobby_create" }
  | { type: "lobby_join"; lobbyId: string }
  | { type: "ready"; ready: boolean }
  | { type: "queue_join"; region?: string }
  | { type: "queue_leave" }
  | { type: "match_leave"; matchId: string }
  | { type: "webrtc_signal"; matchId: string; targetPlayerId: string; signal: WebRTCSignal }
  | { type: "input"; matchId: string; playerId: string; frame: number; input: CombatInput }
  | {
      type: "match_result";
      matchId: string;
      winnerId: string;
      playerOneRounds: number;
      playerTwoRounds: number;
      durationSeconds: number;
    }
  | { type: "ping"; sentAt: number };

export type ServerMessage =
  | { type: "welcome"; connectionId: string }
  | { type: "authenticated"; playerId: string; userId: string; guest: boolean; resumeToken: string; resumed: boolean }
  | { type: "error"; code: string; message: string }
  | { type: "lobby_created"; lobbyId: string }
  | { type: "lobby_state"; lobbyId: string; players: LobbyPlayer[] }
  | { type: "queue_joined" }
  | { type: "queue_left" }
  | { type: "match_found"; matchId: string; players: string[]; playerSlot: number; startFrame: number }
  | { type: "input"; matchId: string; playerId: string; frame: number; input: CombatInput }
  | { type: "match_result_accepted"; matchId: string }
  | { type: "peer_disconnected"; playerId: string }
  | { type: "peer_reconnected"; playerId: string }
  | { type: "webrtc_signal"; matchId: string; fromPlayerId: string; signal: WebRTCSignal }
  | { type: "pong"; sentAt: number; serverAt: number };

export type LobbyPlayer = { id: string; ready: boolean };

