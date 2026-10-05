import "dotenv/config";

function integerEnv(name: string, fallback: number): number {
  const value = Number.parseInt(process.env[name] ?? String(fallback), 10);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${name} must be a positive integer`);
  }
  return value;
}

function booleanEnv(name: string, fallback: boolean): boolean {
  const value = process.env[name];
  if (value === undefined) return fallback;
  return value.toLowerCase() === "true" || value === "1";
}

export const config = {
  port: integerEnv("PORT", 8080),
  host: process.env.HOST ?? "0.0.0.0",
  allowedOrigins: new Set(
    (process.env.ALLOWED_ORIGINS ?? "http://localhost:8060,http://localhost:3000")
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
  ),
  supabaseUrl: process.env.SUPABASE_URL,
  supabaseAnonKey: process.env.SUPABASE_ANON_KEY,
  supabaseServiceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY,
  requireAuth: booleanEnv("REQUIRE_AUTH", false),
  messagesPerSecond: integerEnv("MESSAGES_PER_SECOND", 180),
  reconnectWindowMs: integerEnv("RECONNECT_WINDOW_MS", 15_000),
} as const;

