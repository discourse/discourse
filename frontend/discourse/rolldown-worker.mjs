/* eslint-disable no-console */

import AnsiToHtml from "ansi-to-html";
import * as fs from "fs";
import * as path from "path";

const ansiConverter = new AnsiToHtml({ newline: true, escapeXML: true });

function ansiToHtml(str) {
  if (str != null) {
    return ansiConverter.toHtml(str);
  }
}

const MANIFEST_DIR = path.resolve("./dist/manifest");
const BUILD_STATUS_FILE = path.join(MANIFEST_DIR, "build.json");

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

const { dev } = await import("rolldown/experimental");
const { buildConfig } = await import("./rolldown.config.mjs");

fs.rmSync("./dist", { recursive: true, force: true });
fs.mkdirSync("./dist");
writeBuildStatus({ status: "building" });

console.log("Starting dev server...");

let buildStart = Date.now();
let initialBuild = true;
let hasError = false;

const resolvedConfig = buildConfig({ devMode: true });
const devEngine = await dev(resolvedConfig, resolvedConfig.output, {
  onHmrUpdates: (result) => {
    if (result instanceof Error) {
      console.error("Build error:", result.message);
      writeBuildStatus({
        status: "error",
        error: serializeError(result),
      });
      hasError = true;
      setTimeout(() => {}, 1000);
      return;
    }

    console.log("Changed files:", result.changedFiles);
    hasError = false;
    buildStart = Date.now();
  },
  onOutput: (result) => {
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

    console.log(`Build complete: ${result.output.length} files`);
    if (initialBuild) {
      initialBuild = false;
      console.log(
        `Initial build complete in ${(Date.now() - buildStart) / 1000.0}s`
      );
    } else {
      console.log(`Rebuild complete in ${(Date.now() - buildStart) / 1000.0}s`);
    }
    writeBuildStatus({ status: "ok" });
  },
  rebuildStrategy: "always",
  watch: {},
});

await devEngine.run();
