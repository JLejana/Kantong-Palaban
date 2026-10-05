# Database and security

`database/schema.sql` is the canonical schema. `database/migrations/001_initial_schema.sql` is a standalone equivalent and the seed file inserts only the two fictional development fighters.

RLS permits public character/ranking reads, authenticated profile ownership, and players reading their own match/unlock records. A signup trigger creates the profile and ranking row. Column grants limit self-service profile changes to username, display name, and avatar URL. There are intentionally no client write policies for results, rankings, unlocks, coins, XP, wins, or losses. Trusted server operations use the service role from server-side environment variables only.

`settle_verified_match` atomically validates and inserts a server-confirmed match, updates both ratings/records, and creates a match audit event. Execute permission is restricted to `service_role`. Operational retention and formal dispute policy remain deployment/business policies rather than client features.

