import { ember } from "@embroider/vite";
import * as fs from "fs";
import {
  dev,
  viteAliasPlugin,
  viteImportGlobPlugin,
} from "rolldown/experimental";
import writeResolverConfig from "./lib/embroider-vite-resolver-options.mjs";
import maybeBabel from "./lib/vite-maybe-babel.mjs";

writeResolverConfig(
  {
    staticAppPaths: ["static", "admin"],
    splitAtRoutes: [{ type: "string", value: "wizard" }],
  },
  {
    options: {
      staticInvokables: false,
      allowUnsafeDynamicComponents: false,
    },
  }
);

const extensions = [".gjs", ".mjs", ".js", ".mts", ".gts", ".ts", ".hbs"];

const aliases = [
  { find: "pretty-text", replacement: "pretty-text/addon" },
  {
    find: "ember-buffered-proxy/proxy",
    replacement: "ember-buffered-proxy/addon/proxy",
  },

  {
    find: "@ember-decorators/object",
    replacement: "@ember-decorators/object/addon",
  },
  {
    find: "@ember-decorators/utils/decorator",
    replacement: "@ember-decorators/utils/addon/decorator",
  },
  {
    find: "@ember-decorators/utils/collapse-proto",
    replacement: "@ember-decorators/utils/addon/collapse-proto",
  },
  {
    find: "@ember-decorators/component",
    replacement: "@ember-decorators/component/addon",
  },

  {
    find: "ember-exam/test-support/load",
    replacement: "ember-exam/addon-test-support/load",
  },
  {
    find: "@ember/render-modifiers",
    replacement: "@ember/render-modifiers/addon",
  },
];

fs.rmSync("./dist", { recursive: true, force: true });

const devEngine = await dev(
  {
    resolve: {
      extensions,
    },
    experimental: {
      incrementalBuild: true,
    },
    input: {
      discourse: "discourse.js",
      vendor: "vendor.js",
      "start-discourse": "start-discourse.js",
      "media-optimization-bundle": "media-optimization-bundle.js",
      ...(process.env.NODE_ENV !== "production" || process.env.FORCE_BUILD_TESTS
        ? {
            // tests: "tests/index.html",
            "tests/test-entrypoint": "tests/test-entrypoint.js",
          }
        : undefined),
    },
    preserveEntrySignatures: "strict",
    plugins: [
      viteAliasPlugin({ entries: aliases }),
      ember(),
      viteImportGlobPlugin(),
      maybeBabel({
        babelHelpers: "runtime",
        extensions,
        parallel: true,
        skipPreflightCheck: true,
      }),
      {
        name: "resolve-externals",
        resolveId(source) {
          if (
            source.startsWith("/extra-locales/") ||
            source.startsWith("/bootstrap/")
          ) {
            return { external: true, id: source };
          }
        },
      },
      {
        name: "css-loader",
        load(id) {
          if (id.endsWith(".css")) {
            return {
              code: "",
              moduleType: "js",
            };
          }
          return null;
        },
      },
      {
        name: "bundle-manifest",
        generateBundle(_outputOptions, bundle) {
          console.log("Generate bundle");
          const manifest = {};

          for (const [fileName, chunk] of Object.entries(bundle)) {
            if (chunk.type === "chunk") {
              manifest[`${chunk.name}.js`] = {
                file: fileName,
                name: chunk.name,
                isEntry: chunk.isEntry,
                isDynamicEntry: chunk.isDynamicEntry,
                imports: chunk.imports,
              };
            }
            if (chunk.code?.includes("foobar")) {
              console.log("Found foobar in", fileName);
            }
          }

          // this.emitFile({
          //   type: "asset",
          //   fileName: "manifest.json",
          //   source: JSON.stringify(manifest, null, 2),
          // });

          fs.writeFileSync(
            "./dist/manifest.json",
            JSON.stringify(manifest, null, 2)
          );
        },
      },
    ],
  },
  {
    minify: false,
    dir: "dist",
    sourcemap: true,
    // cleanDir: true,
    hashCharacters: "base36",
    assetFileNames: "assets/[name]-[hash].digested[extname]",
    chunkFileNames: "assets/[name]-[hash].digested.js",
    entryFileNames: "assets/[name]-[hash].digested.js",
  },
  {
    onHmrUpdates: (result) => {
      if (!(result instanceof Error)) {
        console.log("Changed files:", result.changedFiles);
      }
    },
    onOutput: (result) => {
      if (result instanceof Error) {
        console.error("Build error:", result.message);
        return;
      }
      console.log(`Build complete: ${result.output.length} files`);
    },
    rebuildStrategy: "always", // 'always' | 'auto' | 'never'
    watch: {
      skipWrite: false, // Write to disk (this is the default)
      usePolling: false, // Use native fs events
      useDebounce: true, // Debounce rapid changes
      debounceDuration: 10, // ms
    },
  }
);

console.log("Starting dev server...", devEngine);

// devEngine.registerModules("fake", ["discourse"]);

await devEngine.run();
