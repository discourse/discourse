import { ember } from "@embroider/vite";
import { viteAliasPlugin, viteImportGlobPlugin } from "rolldown/experimental";
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

export default {
  resolve: {
    extensions,
  },
  experimental: {
    incrementalBuild: false,
  },
  input: {
    discourse: "discourse.js",
    vendor: "vendor.js",
    "start-discourse": "start-discourse.js",
    "media-optimization-bundle": "media-optimization-bundle.js",
    // ...(process.env.NODE_ENV !== "production" || process.env.FORCE_BUILD_TESTS
    //   ? {
    //       tests: "tests/index.html",
    //       "tests/test-entrypoint": "tests/test-entrypoint.js",
    //     }
    //   : undefined),
  },
  output: {
    minify: false,
    dir: "dist",
    sourcemap: true,
    cleanDir: true,
    hashCharacters: "base36",
    assetFileNames: "assets/[name]-[hash].digested[extname]",
    chunkFileNames: "assets/[name]-[hash].digested.js",
    entryFileNames: "assets/[name]-[hash].digested.js",
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
            code: "", //"export default {};",
            moduleType: "js",
          };
        }
        return null;
      },
    },
    {
      name: "bundle-manifest",
      generateBundle(_outputOptions, bundle) {
        // Options
        const name = "manifest.json";
        const manifest = {};

        for (const [fileName, chunk] of Object.entries(bundle)) {
          // if (chunk.type === "asset") {
          //   manifest[fileName] = {
          //     type: chunk.type,
          //     data: data
          //       ? Buffer.from(chunk.source).toString("base64")
          //       : undefined,
          //     sha256: createHash("sha256")
          //       .update(chunk.source)
          //       .digest("base64"),
          //   };
          // }

          if (chunk.type === "chunk") {
            manifest[`${chunk.name}.js`] = {
              file: fileName,
              name: chunk.name,
              isEntry: chunk.isEntry,
              isDynamicEntry: chunk.isDynamicEntry,
              imports: chunk.imports,
              // type: chunk.type,
              // data: data
              //   ? Buffer.from(chunk.code).toString("base64")
              //   : undefined,
              // mime: "application/javascript",
              // sha256: createHash("sha256").update(chunk.code).digest("base64"),
              // dynamicImports: chunk.dynamicImports,
              // isImplicitEntry: chunk.isImplicitEntry,
            };
          }
        }

        this.emitFile({
          type: "asset",
          fileName: name,
          source: JSON.stringify(manifest, null, 2),
        });
      },
    },
  ],
};
