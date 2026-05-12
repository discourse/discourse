#!/usr/bin/env node
/* eslint-disable no-console */

import { spawn } from "child_process";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import AnsiToHtml from "ansi-to-html";

const ansiConverter = new AnsiToHtml({ newline: true, escapeXML: true });

function ansiToHtml(str) {
  if (str == null) {
    return null;
  }
  return ansiConverter.toHtml(String(str));
}

const CHILD_ENV_FLAG = "DISCOURSE_ROLLDOWN_DEV_CHILD";
const MANIFEST_DIR = path.resolve("./dist/manifest");
const BUILD_STATUS_FILE = path.join(MANIFEST_DIR, "build.json");
const RESTART_DELAY_MS = 5000;

function writeBuildStatus(status) {
  fs.mkdirSync(MANIFEST_DIR, { recursive: true });
  const payload = {
    pid: process.pid,
    timestamp: new Date().toISOString(),
    ...status,
  };
  fs.writeFileSync(BUILD_STATUS_FILE, JSON.stringify(payload, null, 2));
}

function serializeError(err) {
  const base = (rawMessage) => ({
    message: rawMessage,
    messageHtml: ansiToHtml(rawMessage),
  });
  if (err == null) {
    return base("Unknown error");
  }
  if (err instanceof Error) {
    return { ...base(err.message), name: err.name };
  }
  if (typeof err === "object") {
    return {
      ...base(err.message ?? String(err)),
      location: err.loc || err.location,
      frame: ansiToHtml(err.frame || err.codeFrame),
      id: err.id,
    };
  }
  return base(String(err));
}

if (process.env[CHILD_ENV_FLAG] === "1") {
  await runWorker();
} else {
  await runSupervisor();
}

async function runWorker() {
  const { dev } = await import("rolldown/experimental");
  const { buildConfig } = await import("./rolldown.config.mjs");

  fs.rmSync("./dist", { recursive: true, force: true });
  fs.mkdirSync("./dist");
  writeBuildStatus({ status: "building" });

  console.log("Starting dev server...");

  let buildStart = Date.now();
  let initialBuild = true;

  const resolvedConfig = buildConfig({ devMode: true });
  const devEngine = await dev(resolvedConfig, resolvedConfig.output, {
    onHmrUpdates: (result) => {
      if (!(result instanceof Error)) {
        console.log("Changed files:", result.changedFiles);
        buildStart = Date.now();
      }
    },
    onOutput: (result) => {
      if (result instanceof Error) {
        console.error("Build error:", result.message);
        writeBuildStatus({
          status: "error",
          error: serializeError(result),
        });
        return;
      }
      console.log(`Build complete: ${result.output.length} files`);
      if (initialBuild) {
        initialBuild = false;
        console.log(
          `Initial build complete in ${(Date.now() - buildStart) / 1000.0}s`
        );
      } else {
        console.log(
          `Rebuild complete in ${(Date.now() - buildStart) / 1000.0}s`
        );
      }
      writeBuildStatus({ status: "ok" });
    },
    rebuildStrategy: "always",
    watch: {},
  });

  await devEngine.run();
}

async function runSupervisor() {
  const scriptPath = fileURLToPath(import.meta.url);
  let shuttingDown = false;
  let child = null;

  const forwardSignal = (signal) => {
    shuttingDown = true;
    if (child) {
      try {
        child.kill(signal);
      } catch {
        // ignore
      }
    }
  };

  process.on("SIGINT", () => forwardSignal("SIGINT"));
  process.on("SIGTERM", () => forwardSignal("SIGTERM"));
  process.on("SIGHUP", () => forwardSignal("SIGHUP"));

  while (!shuttingDown) {
    const proc = spawn(process.execPath, [scriptPath], {
      env: { ...process.env, [CHILD_ENV_FLAG]: "1" },
      stdio: "inherit",
    });
    child = proc;

    const { code, signal } = await new Promise((resolve) => {
      proc.once("exit", (c, s) => resolve({ code: c, signal: s }));
    });
    child = null;

    if (shuttingDown) {
      process.exit(code ?? 1);
    }

    const reason = signal
      ? `terminated by signal ${signal}`
      : `exited with code ${code}`;
    console.error(
      `\n[rolldown-dev] Rolldown dev process ${reason}. Restarting in ${RESTART_DELAY_MS / 1000}s...`
    );

    await new Promise((r) => setTimeout(r, RESTART_DELAY_MS));
  }
}
