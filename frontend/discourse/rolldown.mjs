#!/usr/bin/env node
/* eslint-disable no-console */

import { spawn } from "child_process";
import chokidar from "chokidar";
import * as fs from "fs";
import * as path from "path";

const WORKER_PATH = "./rolldown-worker.mjs";
const REBUILD_IN_FLIGHT_FILE = path.resolve(
  "./dist/manifest/.rebuild-in-flight"
);
const WATCH_DIR = "./app";

let shuttingDown = false;
let child = null;
let immediateRetryUsed = false;

function forwardSignal(signal) {
  shuttingDown = true;
  if (child) {
    try {
      child.kill(signal);
    } catch {
      // ignore
    }
  }
}

function isShuttingDown() {
  return shuttingDown;
}

function readPendingFiles() {
  try {
    const raw = fs.readFileSync(REBUILD_IN_FLIGHT_FILE, "utf8");
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return null;
  }
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

process.on("SIGINT", () => forwardSignal("SIGINT"));
process.on("SIGTERM", () => forwardSignal("SIGTERM"));
process.on("SIGHUP", () => forwardSignal("SIGHUP"));

while (!shuttingDown) {
  fs.rmSync(REBUILD_IN_FLIGHT_FILE, { force: true });

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
  const pendingFiles = readPendingFiles();

  if (pendingFiles) {
    immediateRetryUsed = false;
    const what = pendingFiles.length
      ? `rebuilding ${pendingFiles.join(", ")}`
      : "an in-flight rebuild";
    console.error(
      `\n[rolldown] Worker ${reason} while ${what}. Waiting for a file change in ${WATCH_DIR} before restarting...`
    );
    const changed = await waitForFileChange(WATCH_DIR, isShuttingDown);
    if (!changed || shuttingDown) {
      process.exit(code ?? 1);
    }
    console.error("[rolldown] File change detected. Restarting...");
  } else {
    if (immediateRetryUsed) {
      console.error(
        `\n[rolldown] Worker ${reason} with no in-flight rebuild. Already retried once — exiting.`
      );
      process.exit(code ?? 1);
    }
    immediateRetryUsed = true;
    console.error(
      `\n[rolldown] Worker ${reason} with no in-flight rebuild. Restarting immediately...`
    );
  }
}
