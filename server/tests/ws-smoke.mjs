import { spawn } from "node:child_process";
import process from "node:process";
import WebSocket from "ws";

const port = 18081;
const server = spawn(process.execPath, ["dist/index.js"], {
  env: { ...process.env, PORT: String(port), HOST: "127.0.0.1", ALLOWED_ORIGINS: "" },
  stdio: ["ignore", "pipe", "pipe"],
});

function waitForServer() {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error("Server startup timed out")), 5000);
    server.stdout.on("data", (chunk) => {
      if (chunk.toString().includes("listening")) {
        clearTimeout(timeout);
        resolve();
      }
    });
    server.stderr.on("data", (chunk) => reject(new Error(chunk.toString())));
    server.once("exit", (code) => reject(new Error(`Server exited early with ${code}`)));
  });
}

function connectClient() {
  const socket = new WebSocket(`ws://127.0.0.1:${port}`);
  const queued = [];
  const waiters = [];
  socket.on("message", (raw) => {
    const message = JSON.parse(raw.toString());
    const index = waiters.findIndex((waiter) => waiter.type === message.type);
    if (index >= 0) {
      const [waiter] = waiters.splice(index, 1);
      waiter.resolve(message);
    } else {
      queued.push(message);
    }
  });
  const waitFor = (type) => {
    const index = queued.findIndex((message) => message.type === type);
    if (index >= 0) return Promise.resolve(queued.splice(index, 1)[0]);
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${type}`)), 3000);
      waiters.push({
        type,
        resolve: (message) => {
          clearTimeout(timer);
          resolve(message);
        },
      });
    });
  };
  return { socket, waitFor };
}

try {
  await waitForServer();
  let first = connectClient();
  const second = connectClient();
  await Promise.all([
    first.waitFor("welcome"),
    second.waitFor("welcome"),
  ]);
  first.socket.send(JSON.stringify({ type: "authenticate", accessToken: "", resumeToken: "" }));
  second.socket.send(JSON.stringify({ type: "authenticate", accessToken: "", resumeToken: "" }));
  const [firstAuth, secondAuth] = await Promise.all([
    first.waitFor("authenticated"),
    second.waitFor("authenticated"),
  ]);

  first.socket.close();
  await new Promise((resolve) => first.socket.once("close", resolve));
  first = connectClient();
  await first.waitFor("welcome");
  first.socket.send(JSON.stringify({ type: "authenticate", accessToken: "", resumeToken: firstAuth.resumeToken }));
  const resumed = await first.waitFor("authenticated");
  if (!resumed.resumed || resumed.playerId !== firstAuth.playerId) throw new Error("Reconnect did not preserve player identity");

  first.socket.send(JSON.stringify({ type: "queue_join" }));
  await first.waitFor("queue_joined");
  second.socket.send(JSON.stringify({ type: "queue_join" }));
  await second.waitFor("queue_joined");
  const [firstMatch, secondMatch] = await Promise.all([
    first.waitFor("match_found"),
    second.waitFor("match_found"),
  ]);
  if (firstMatch.matchId !== secondMatch.matchId) throw new Error("Clients joined different rooms");

  first.socket.send(JSON.stringify({
    type: "input", matchId: firstMatch.matchId, playerId: "spoofed-player", frame: 0,
    input: { left: false, right: false, jump: false, crouch: false, lp: false, rp: false, lk: false, rk: false, block: false },
  }));
  const rejectedInput = await first.waitFor("error");
  if (rejectedInput.code !== "invalid_input") throw new Error("Spoofed input was not rejected");

  first.socket.send(JSON.stringify({
    type: "input",
    matchId: firstMatch.matchId,
    playerId: resumed.playerId,
    frame: 0,
    input: { left: false, right: true, jump: false, crouch: false, lp: true, rp: false, lk: false, rk: false, block: false },
  }));
  const relayed = await second.waitFor("input");
  if (relayed.playerId !== resumed.playerId || relayed.frame !== 0) throw new Error("Input relay changed identity or frame");

  second.socket.send(JSON.stringify({ type: "ping", sentAt: 123 }));
  const pong = await second.waitFor("pong");
  if (pong.sentAt !== 123 || secondAuth.playerId === resumed.playerId) throw new Error("Ping or identity validation failed");

  const result = {
    type: "match_result",
    matchId: firstMatch.matchId,
    winnerId: resumed.playerId,
    playerOneRounds: 2,
    playerTwoRounds: 0,
    durationSeconds: 30,
  };
  second.socket.send(JSON.stringify({ ...result, winnerId: secondAuth.playerId }));
  const impossibleWinner = await second.waitFor("error");
  if (impossibleWinner.code !== "invalid_result") throw new Error("Winner/score mismatch was not rejected");
  first.socket.send(JSON.stringify(result));
  await first.waitFor("match_result_accepted");
  second.socket.send(JSON.stringify({ ...result, winnerId: secondAuth.playerId, playerOneRounds: 0, playerTwoRounds: 2 }));
  const conflict = await second.waitFor("error");
  if (conflict.code !== "invalid_result") throw new Error("Conflicting result was not rejected");
  first.socket.send(JSON.stringify(result));
  await first.waitFor("match_result_accepted");
  second.socket.send(JSON.stringify(result));
  await second.waitFor("match_result_accepted");

  first.socket.close();
  second.socket.close();
  console.log("WEBSOCKET_SMOKE_TEST: PASS");
} finally {
  server.kill();
}

