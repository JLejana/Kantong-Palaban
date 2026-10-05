import { config } from "../config/env.js";

export type PersistedMatchResult = {
  matchId: string;
  playerOneId: string;
  playerTwoId: string;
  winnerId: string;
  playerOneRounds: number;
  playerTwoRounds: number;
  durationSeconds: number;
};

export async function persistMatchResult(result: PersistedMatchResult): Promise<boolean> {
  if (!config.supabaseUrl || !config.supabaseServiceRoleKey) return false;
  const response = await fetch(`${config.supabaseUrl}/rest/v1/rpc/settle_verified_match`, {
    method: "POST",
    headers: {
      apikey: config.supabaseServiceRoleKey,
      authorization: `Bearer ${config.supabaseServiceRoleKey}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      p_match_id: result.matchId,
      p_player_1_id: result.playerOneId,
      p_player_2_id: result.playerTwoId,
      p_winner_id: result.winnerId,
      p_player_1_rounds: result.playerOneRounds,
      p_player_2_rounds: result.playerTwoRounds,
      p_duration_seconds: result.durationSeconds,
    }),
  });
  if (!response.ok) console.error("Supabase match settlement rejected", response.status, await response.text());
  return response.ok;
}

