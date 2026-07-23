import * as fs from "fs";
import { basename, relative } from "path";
import { viteAliasPlugin, viteImportGlobPlugin } from "rolldown/experimental";
import discourseChunkNamesPlugin from "./lib/discourse-chunk-names.mjs";
import dynamicChunkUrlPlugin from "./lib/dynamic-chunk-url-plugin.mjs";
import writeResolverConfig from "./lib/embroider-vite-resolver-options.mjs";
import maybeBabel from "./lib/maybe-babel.mjs";
import optimizedEmber from "./lib/optimized-ember.mjs";
import { exitIfDevServerRunning } from "./lib/rolldown-devserver-lock.mjs";
import wrapTestModulesPlugin from "./lib/wrap-test-modules-plugin.mjs";

exitIfDevServerRunning();

writeResolverConfig(
  {
    staticAppPaths: ["static", "admin", "workers"],
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
  {
    find: "ember-buffered-proxy/helpers",
    replacement: "ember-buffered-proxy/addon/helpers",
  },
  {
    find: "ember-buffered-proxy/mixin",
    replacement: "ember-buffered-proxy/addon/mixin",
  },
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

export function buildConfig({ devMode } = {}) {
  const isProduction = process.env.EMBER_ENV === "production";

  if (!isProduction) {
    process.env.NODE_ENV = "development";
  }

  return {
    tsconfig: false,
    resolve: {
      extensions,
    },
    experimental: {
      incrementalBuild: true,
      resolveNewUrlToAsset: true,
      nativeMagicString: true,
    },
    moduleTypes: {
      ".wasm": "asset",
      ".gjs": "js",
      ".gts": "ts",
    },
    input: {
      discourse: "discourse.js",
      vendor: "vendor.js",
      ...(!isProduction || process.env.FORCE_BUILD_TESTS
        ? {
            "test-entrypoint": "tests/test-entrypoint.js",
            "qunit-live-reload": "qunit-live-reload.js",
          }
        : undefined),
    },
    output: {
      minify: isProduction,
      dir: "dist",
      sourcemap: true,
      cleanDir: !devMode,
      hashCharacters: "base36",
      assetFileNames: "assets/js/[name]-[hash].digested[extname]",
      chunkFileNames: "assets/js/[name]-[hash].digested.js", // See also: discourseChunkNamesPlugin
      entryFileNames: "assets/js/[name]-[hash].digested.js",
    },
    watch: {
      clearScreen: false,
    },
    plugins: [
      viteAliasPlugin({ entries: aliases }),
      dynamicChunkUrlPlugin(),
      optimizedEmber(),
      viteImportGlobPlugin(),
      maybeBabel({
        babelHelpers: "runtime",
        extensions,
        parallel: true,
        skipPreflightCheck: true, // Skip per-file config verification
        babelrc: false, // Skip per-file `.babelrc`/`.babelignore` checks
      }),
      wrapTestModulesPlugin(),
      discourseChunkNamesPlugin(),
      {
        name: "forbid-plugin-imports",
        resolveId: {
          filter: { id: /^discourse\/plugins\// },
          handler(source, importer) {
            this.error(
              `Forbidden import of plugin module "${source}"` +
                (importer
                  ? ` from ${relative(import.meta.dirname, importer)}`
                  : "") +
                ". Core cannot import plugin modules."
            );
          },
        },
      },
      {
        name: "css-loader",
        transform: {
          filter: {
            id: /\.css$/,
          },
          handler(code, id) {
            return {
              code: `
                const style = document.createElement("style");
                style.innerHTML = ${JSON.stringify(code)};
                style.dataset.rolldownModuleId = ${JSON.stringify(relative(import.meta.dirname, id))};
                document.head.append(style);
              `,
              moduleType: "js",
              map: { mappings: "" },
            };
          },
        },
      },
      {
        name: "move-sourcemaps",
        generateBundle(_options, bundle) {
          const mapEntries = Object.entries(bundle).filter(([f]) =>
            f.endsWith(".map")
          );

          for (const [oldFileName, asset] of mapEntries) {
            // assets/js/foo.js.map → assets/map/foo.js.map
            const newFileName = oldFileName.replace(
              /^assets\/js\//,
              "assets/map/"
            );

            this.emitFile({
              type: "asset",
              fileName: newFileName,
              source: asset.source,
            });

            delete bundle[oldFileName];

            // Patch the corresponding JS chunk
            const jsFileName = oldFileName.slice(0, -4);
            const chunk = bundle[jsFileName];
            if (chunk?.code) {
              chunk.code = chunk.code.replace(
                /\/\/# sourceMappingURL=.+/,
                `//# sourceMappingURL=../map/${basename(oldFileName)}`
              );
            }
          }
        },
      },
      {
        name: "bundle-manifest",
        generateBundle(_outputOptions, bundle) {
          const manifest = {
            entrypoints: {},
            dynamicEntrypoints: {},
            chunks: {},
          };

          for (const [fileName, chunk] of Object.entries(bundle)) {
            if (chunk.type !== "chunk") {
              continue;
            }

            const facadeModuleId = chunk.facadeModuleId
              ? relative(import.meta.dirname, chunk.facadeModuleId)
              : null;

            if (chunk.isEntry) {
              manifest.entrypoints[chunk.name] = fileName;
            } else if (
              chunk.isDynamicEntry &&
              facadeModuleId &&
              !facadeModuleId.startsWith("../")
            ) {
              manifest.dynamicEntrypoints[facadeModuleId] = fileName;
            }

            manifest.chunks[fileName] = {
              file: fileName,
              facadeModuleId,
              name: chunk.name,
              isEntry: chunk.isEntry,
              isDynamicEntry: chunk.isDynamicEntry,
              imports: chunk.imports,
            };
          }

          if (devMode) {
            // Workaround rolldown devEngine bug?
            fs.mkdirSync("./dist/manifest", { recursive: true });
            fs.writeFileSync(
              "./dist/manifest/manifest.json",
              JSON.stringify(manifest, null, 2)
            );
          } else {
            this.emitFile({
              type: "asset",
              fileName: "manifest/manifest.json",
              source: JSON.stringify(manifest, null, 2),
            });
          }
        },
      },
    ],
  };
}

export default buildConfig({ devMode: false });
