// See: https://esbuild.github.io/plugins/#webassembly-plugin

// import * as esbuild from "esbuild";
// import path from "node:path";
// import fs from "node:fs";
// import { argv } from "node:process";
const esbuild = require("esbuild");
const path = require("node:path");
const fs = require("node:fs");
const { argv } = require("node:process");

let wasmPlugin = {
  name: "wasm",

  setup(build) {
    build.onResolve({ filter: /\.wasm$/ }, (args) => {
      if (args.namespace === "wasm-stub") {
        return {
          path: args.path,
          namespace: "wasm-binary",
        };
      }

      if (args.resolveDir === "") {
        return;
      }

      return {
        path: path.isAbsolute(args.path)
          ? args.path
          : path.join(args.resolveDir, args.path),
        namespace: "wasm-stub",
      };
    });

    build.onLoad({ filter: /.*/, namespace: "wasm-stub" }, async (args) => {
      return {
        contents: `import wasm from ${JSON.stringify(args.path)};
        export default (imports) => {
          const wasmModule = new WebAssembly.Module(wasm);
          const wasmInstance = new WebAssembly.Instance(wasmModule, imports);
          return wasmInstance.exports;
        };`,
      };
    });

    build.onLoad({ filter: /.*/, namespace: "wasm-binary" }, async (args) => {
      return {
        contents: await fs.promises.readFile(args.path),
        loader: "binary",
      };
    });
  },
};

esbuild
  .build({
    logLevel: "warning",
    bundle: true,
    // minify: true,
    external: ["fs"],
    alias: {
      path: "./app/assets/javascripts/node_modules/path-browserify",
      util: "./app/assets/javascripts/node_modules/@zxing/text-encoding",
    },
    define: {
      process: `{ "env": {} }`,
    },
    entryPoints: ["./app/assets/javascripts/js-processor.js"],
    outfile: argv[2],
    plugins: [wasmPlugin],
  })
  .then(async () => {
    const data = await fs.promises.readFile(argv[2], { encoding: "utf8" });
    const newData = data.replace(/module.require/g, "__require");
    await fs.promises.writeFile(argv[2], newData);
  });
