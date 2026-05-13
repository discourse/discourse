#!/usr/bin/env node
/* eslint-disable no-console */

import { spawn } from "child_process";
import chokidar from "chokidar";
import { once } from "events";
import * as fs from "fs";

const WORKER_PATH = "./rolldown-worker.mjs";
const REBUILD_IN_FLIGHT_FILE = "./dist/manifest/.rebuild-in-flight";
const WATCH_DIR = "./app";
const shutdown = new AbortController();

let child = null;
let immediateRetryUsed = false;

for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) {
  process.on(sig, () => handleSignal(sig));
}

function handleSignal(sig) {
  shutdown.abort();
  child?.kill(sig);
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

// Observes WATCH_DIR recursively for any change.
async function waitForFileChange() {
  const watcher = chokidar.watch(WATCH_DIR, {
    ignoreInitial: true,
  });
  try {
    await once(watcher, "all", { signal: shutdown.signal });
    return true;
  } catch {
    return !shutdown.signal.aborted;
  } finally {
    await watcher.close();
  }
}

while (!shutdown.signal.aborted) {
  fs.rmSync(REBUILD_IN_FLIGHT_FILE, { force: true });

  const proc = spawn(process.execPath, [WORKER_PATH], { stdio: "inherit" });
  child = proc;

  const { code, signal } = await new Promise((resolve) => {
    proc.once("exit", (c, s) => resolve({ code: c, signal: s }));
  });
  child = null;

  if (shutdown.signal.aborted) {
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
      `\nWorker ${reason} while ${what}. Waiting for a file change in ${WATCH_DIR} before restarting...`
    );
    const changed = await waitForFileChange();
    if (!changed) {
      process.exit(code ?? 1);
    }
    console.error("File change detected. Restarting...");
  } else {
    if (immediateRetryUsed) {
      console.error(
        `\nWorker ${reason} with no in-flight rebuild. Already retried once — exiting.`
      );
      process.exit(code ?? 1);
    }
    immediateRetryUsed = true;
    console.error(
      `\nWorker ${reason} with no in-flight rebuild. Restarting immediately...`
    );
  }
}
