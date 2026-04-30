import { ember } from "@embroider/vite";
import * as fs from "fs";
import { basename } from "path";
import { viteAliasPlugin, viteImportGlobPlugin } from "rolldown/experimental";
import writeResolverConfig from "./lib/embroider-vite-resolver-options.mjs";
import maybeBabel from "./lib/maybe-babel.mjs";
import wrapTestModulesPlugin from "./lib/wrap-test-modules-plugin.mjs";

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

export function buildConfig({ devMode } = {}) {
  if (process.env.EMBER_ENV !== "production") {
    process.env.NODE_ENV = "development";
  }

  return {
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
      ...(process.env.EMBER_ENV !== "production" ||
      process.env.FORCE_BUILD_TESTS
        ? { "tests/test-entrypoint": "tests/test-entrypoint.js" }
        : undefined),
    },
    output: {
      minify: false,
      dir: "dist",
      sourcemap: true,
      cleanDir: !devMode,
      hashCharacters: "base36",
      assetFileNames: "assets/js/[name]-[hash].digested[extname]",
      chunkFileNames: "assets/js/[name]-[hash].digested.js",
      entryFileNames: "assets/js/[name]-[hash].digested.js",
    },
    watch: {
      clearScreen: false,
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
      wrapTestModulesPlugin(),
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
