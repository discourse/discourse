// See: https://esbuild.github.io/plugins/#webassembly-plugin

const esbuild = require("esbuild");
const path = require("node:path");
const fs = require("node:fs");

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
        contents: `export { default } from ${JSON.stringify(args.path)};`,
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
    minify: false,
    alias: {
      path: "path-browserify",
      url: "./url-polyfill",
      "source-map-js": "source-map-js",
    },
    banner: {
      js: `var process = { "env": { "EMBER_ENV": "production" }, "cwd": () => "/" };`,
    },
    external: [],
    entryPoints: ["./transpiler.js"],
    plugins: [wasmPlugin],
  })
  .then(() => {});
