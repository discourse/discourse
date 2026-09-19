#!/usr/bin/env node
/* eslint-disable no-console */

import AnsiToHtml from "ansi-to-html";
import * as fs from "fs";
import * as path from "path";
import { dev } from "rolldown/experimental";
import {
  BUILD_STATUS_FILE,
  MANIFEST_DIR,
} from "./lib/rolldown-devserver-lock.mjs";
import { buildConfig } from "./rolldown.config.mjs";

const ansiConverter = new AnsiToHtml({ newline: true, escapeXML: true });
const CWD_PREFIX = `${process.cwd()}/`;

let buildStart = Date.now();
let initialBuild = true;
let hasError = false;
let pendingChangedFiles = [];

function ansiToHtml(str) {
  if (str != null) {
    return ansiConverter.toHtml(str);
  }
}

function stripCwd(file) {
  const relative = path.relative(CWD_PREFIX, file);
  return relative;
}

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

fs.rmSync("./dist", { recursive: true, force: true });
fs.mkdirSync("./dist");
writeBuildStatus({ status: "building" });

console.log("Starting rolldown dev server...");

const resolvedConfig = buildConfig({ devMode: true });
const devEngine = await dev(resolvedConfig, resolvedConfig.output, {
  // Avoid `rebuildStrategy: "always"` — it panics in scan_stage_cache when
  // recovering from a parse error. Drive rebuilds manually using ensureLatestBuildOutput.
  onHmrUpdates(result) {
    if (result instanceof Error) {
      console.error("Build error:", result.message);
      writeBuildStatus({
        status: "error",
        error: serializeError(result),
      });
      hasError = true;
      return;
    }

    pendingChangedFiles = result.changedFiles.map(stripCwd);
    hasError = false;
    buildStart = Date.now();
    console.log(`Rebuilding (${pendingChangedFiles.length} changed)...`);
    devEngine.ensureLatestBuildOutput();
  },

  onOutput(result) {
    if (hasError) {
      return;
    } else if (result instanceof Error) {
      console.error("Build error:", result.message);
      writeBuildStatus({
        status: "error",
        error: serializeError(result),
      });
      return;
    }

    const elapsed = ((Date.now() - buildStart) / 1000).toFixed(2);
    const count = result.output.length;
    if (initialBuild) {
      initialBuild = false;
      console.log(`Initial build complete in ${elapsed}s (${count} files)`);
    } else {
      console.log(
        `Rebuild complete in ${elapsed}s (${count} files): ${pendingChangedFiles.join(", ")}`
      );
    }
    writeBuildStatus({ status: "ok" });
  },
});

await devEngine.run();

// run() resolves after the initial build and rolldown's native watcher
// doesn't hold the process open reliably
setInterval(() => {}, 0x7fffffff);
