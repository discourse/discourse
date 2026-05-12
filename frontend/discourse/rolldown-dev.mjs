#!/usr/bin/env node
/* eslint-disable no-console */

import AnsiToHtml from "ansi-to-html";
import { spawn } from "child_process";
import chokidar from "chokidar";
import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";

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
const HEALTHY_RUN_MS = 20_000;
const WATCH_DIR = "./app";

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

  const isShuttingDown = () => shuttingDown;
  let previousRunWasShortLived = false;

  while (!shuttingDown) {
    const startedAt = Date.now();
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
    const ranFor = Date.now() - startedAt;
    const wasShortLived = ranFor < HEALTHY_RUN_MS;

    if (wasShortLived && previousRunWasShortLived) {
      console.error(
        `\n[rolldown-dev] Rolldown dev process ${reason} after ${(ranFor / 1000).toFixed(1)}s (second short-lived run in a row). Waiting for a file change in ${WATCH_DIR} before restarting...`
      );
      const changed = await waitForFileChange(WATCH_DIR, isShuttingDown);
      if (!changed || shuttingDown) {
        process.exit(code ?? 1);
      }
      console.error("[rolldown-dev] File change detected. Restarting...");
    } else {
      console.error(
        `\n[rolldown-dev] Rolldown dev process ${reason}. Restarting...`
      );
    }

    previousRunWasShortLived = wasShortLived;
  }
}

// Watches `dir` recursively for any change. Resolves to `true` on the first
// change, or `false` if `isCancelled()` becomes truthy while we're waiting.
// Uses chokidar so this works uniformly on macOS, Linux, and Windows.
async function waitForFileChange(dir, isCancelled) {
  return await new Promise((resolve) => {
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
