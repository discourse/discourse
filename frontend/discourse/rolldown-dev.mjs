/* eslint-disable no-console */

import * as fs from "fs";
import { dev } from "rolldown/experimental";
import { buildConfig } from "./rolldown.config.mjs";

fs.rmSync("./dist", { recursive: true, force: true });
fs.mkdirSync("./dist");

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
      return;
    }
    console.log(`Build complete: ${result.output.length} files`);
    if (initialBuild) {
      initialBuild = false;
      console.log(`Initial build complete in ${Date.now() - buildStart}ms`);
    } else {
      console.log(`Rebuild complete in ${Date.now() - buildStart}ms`);
    }
  },
  rebuildStrategy: "always",
});

await devEngine.run();
