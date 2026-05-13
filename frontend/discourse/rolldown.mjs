#!/usr/bin/env node
/* eslint-disable no-console */

import { spawn } from "child_process";
import chokidar from "chokidar";
import * as path from "path";
import { fileURLToPath } from "url";

const WORKER_PATH = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "rolldown-worker.mjs"
);
const WATCH_DIR = "./app";

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

const isShuttingDown = () => shuttingDown;

while (!shuttingDown) {
  const proc = spawn(process.execPath, [WORKER_PATH], { stdio: "inherit" });
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
    `\n[rolldown] Worker ${reason}. Waiting for a file change in ${WATCH_DIR} before restarting...`
  );

  const changed = await waitForFileChange(WATCH_DIR, isShuttingDown);
  if (!changed || shuttingDown) {
    process.exit(code ?? 1);
  }
  console.error("[rolldown] File change detected. Restarting...");
}

// Watches `dir` recursively for any change. Resolves to `true` on the first
// change, or `false` if `isCancelled()` becomes truthy while we're waiting.
// Uses chokidar so this works uniformly on macOS, Linux, and Windows.
async function waitForFileChange(dir, isCancelled) {
  return new Promise((resolve) => {
    const watcher = chokidar.watch(dir, {
      ignoreInitial: true,
      ignored: (p) => p.includes("/node_modules/"),
    });

    const cleanup = () => {
      clearInterval(cancelCheck);
      watcher.close();
    };

    const cancelCheck = setInterval(() => {
      if (isCancelled()) {
        cleanup();
        resolve(false);
      }
    }, 100);

    watcher.on("all", () => {
      cleanup();
      resolve(true);
    });
    watcher.on("error", () => {
      cleanup();
      resolve(true);
    });
  });
}
