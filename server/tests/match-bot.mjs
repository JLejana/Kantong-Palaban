import WebSocket from "ws";

const socket = new WebSocket("ws://127.0.0.1:18082");
let playerId = "";

const timeout = setTimeout(() => {
  console.error("MATCH_BOT: timeout");
  process.exit(1);
}, 8000);

socket.on("message", (raw) => {
  const message = JSON.parse(raw.toString());
  if (message.type === "welcome") {
    socket.send(JSON.stringify({ type: "authenticate", accessToken: "", resumeToken: "" }));
  } else if (message.type === "authenticated") {
    playerId = message.playerId;
    socket.send(JSON.stringify({ type: "queue_join", region: "test" }));
  } else if (message.type === "match_found") {
    socket.send(JSON.stringify({
      type: "input",
      matchId: message.matchId,
      playerId,
      frame: 0,
      input: { left: false, right: true, jump: false, crouch: false, lp: false, rp: false, lk: false, rk: false, block: false },
    }));
    clearTimeout(timeout);
    setTimeout(() => socket.close(), 500);
  }
});

