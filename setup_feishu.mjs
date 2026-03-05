import { spawn } from "child_process";
const child = spawn("node", ["openclaw.mjs", "channels", "add", "--channel", "feishu"]);
child.stdout.on("data", (data) => {
  const out = data.toString();
  console.log(out);
  if (out.includes("Install Feishu plugin?")) {
    child.stdin.write("\x1B[B\x1B[B\r"); // Skip for now
  }
});
child.stderr.on("data", (data) => console.error(data.toString()));
child.on("close", (code) => console.log("Exited with", code));
