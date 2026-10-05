import type { ClientMessage, CombatInput, WebRTCSignal } from "../types/protocol.js";

const inputKeys: (keyof CombatInput)[] = [
  "left", "right", "jump", "crouch", "lp", "rp", "lk", "rk", "block",
];

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function validInput(value: unknown): value is CombatInput {
  return isRecord(value) && inputKeys.every((key) => typeof value[key] === "boolean");
}

function parseSignal(value: unknown): WebRTCSignal | null {
  if (!isRecord(value) || typeof value.kind !== "string") return null;
  if ((value.kind === "offer" || value.kind === "answer") && typeof value.sdp === "string" && value.sdp.length <= 100_000) {
    return { kind: value.kind, sdp: value.sdp };
  }
  if (
    value.kind === "ice" && typeof value.mid === "string" && Number.isSafeInteger(value.index) &&
    typeof value.candidate === "string" && value.candidate.length <= 4096
  ) {
    return { kind: "ice", mid: value.mid, index: value.index as number, candidate: value.candidate };
  }
  return null;
}

export function parseClientMessage(raw: string): ClientMessage | null {
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!isRecord(value) || typeof value.type !== "string") return null;

  switch (value.type) {
    case "authenticate":
      return typeof value.accessToken === "string" && typeof value.resumeToken === "string"
        ? { type: value.type, accessToken: value.accessToken.slice(0, 8192), resumeToken: value.resumeToken.slice(0, 128) }
        : null;
    case "lobby_create":
    case "queue_leave":
      return { type: value.type };
    case "lobby_join":
      return typeof value.lobbyId === "string" ? { type: value.type, lobbyId: value.lobbyId } : null;
    case "ready":
      return typeof value.ready === "boolean" ? { type: value.type, ready: value.ready } : null;
    case "queue_join":
      return typeof value.region === "string"
        ? { type: value.type, region: value.region.slice(0, 32) }
        : { type: value.type };
    case "match_leave":
      return typeof value.matchId === "string" ? { type: value.type, matchId: value.matchId } : null;
    case "webrtc_signal": {
      const signal = parseSignal(value.signal);
      return typeof value.matchId === "string" && typeof value.targetPlayerId === "string" && signal
        ? { type: value.type, matchId: value.matchId, targetPlayerId: value.targetPlayerId, signal }
        : null;
    }
    case "input":
      if (
        typeof value.matchId !== "string" || typeof value.playerId !== "string" ||
        !Number.isSafeInteger(value.frame) || (value.frame as number) < 0 || !validInput(value.input)
      ) return null;
      return {
        type: value.type,
        matchId: value.matchId,
        playerId: value.playerId,
        frame: value.frame as number,
        input: value.input,
      };
    case "match_result":
      if (
        typeof value.matchId !== "string" || typeof value.winnerId !== "string" ||
        !Number.isSafeInteger(value.playerOneRounds) || !Number.isSafeInteger(value.playerTwoRounds) ||
        typeof value.durationSeconds !== "number" || value.durationSeconds < 0
      ) return null;
      return {
        type: value.type,
        matchId: value.matchId,
        winnerId: value.winnerId,
        playerOneRounds: value.playerOneRounds as number,
        playerTwoRounds: value.playerTwoRounds as number,
        durationSeconds: value.durationSeconds,
      };
    case "ping":
      return typeof value.sentAt === "number" ? { type: value.type, sentAt: value.sentAt } : null;
    default:
      return null;
  }
}

