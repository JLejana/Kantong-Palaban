import { config } from "../config/env.js";

type SupabaseUser = { id: string; email?: string };

export async function verifyAccessToken(accessToken: string): Promise<SupabaseUser | null> {
  const apiKey = config.supabaseAnonKey ?? config.supabaseServiceRoleKey;
  if (!config.supabaseUrl || !apiKey || accessToken.length < 20) return null;
  const response = await fetch(`${config.supabaseUrl}/auth/v1/user`, {
    headers: { apikey: apiKey, authorization: `Bearer ${accessToken}` },
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) return null;
  const value: unknown = await response.json();
  if (typeof value !== "object" || value === null || !("id" in value) || typeof value.id !== "string") return null;
  return value as SupabaseUser;
}
