import { classicEmberSupport, ember } from "@embroider/vite";
import basicSsl from "@vitejs/plugin-basic-ssl";
import { visualizer } from "rollup-plugin-visualizer";
import { defineConfig } from "vite";
import mkcert from "vite-plugin-mkcert";
import customProxy from "../custom-proxy";
import writeResolverConfig from "./lib/embroider-vite-resolver-options";
import maybeBabel from "./lib/vite-maybe-babel";

const extensions = [".gjs", ".mjs", ".js", ".mts", ".gts", ".ts", ".hbs"];

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

const BUNDLED_DEV = false;

export default defineConfig(({ mode, command }) => {
  const aliases = [
    { find: "pretty-text", replacement: "/../pretty-text/addon" },
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
  // }
  return {
    base: "",
    resolve: {
      extensions,
      alias: aliases,
    },
    experimental: {
      bundledDev: BUNDLED_DEV,
    },
    plugins: [
      // Standard Ember stuff

      ember(),

      // classicEmberSupport(),

      maybeBabel({
        babelHelpers: "runtime",
        extensions,
        parallel: 4,
        skipPreflightCheck: true,
      }),

      // Discourse-specific
      // mkcert(),
      // visualizer({ emitFile: true }),

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
    ],
    server: {
      port: 4200,
      strictPort: true,

      proxy: {
        "/": customProxy({ bundledDev: BUNDLED_DEV }),
      },

      warmup: {
        clientFiles: ["./app/**/*.js", "./app/**/*.gjs"],
      },
    },
    preview: {
      port: 4200,
      strictPort: true,
      proxy: {
        "/": customProxy({ rewriteHtml: false }),
      },
    },
    build: {
      minify: false,
      manifest: true,
      outDir: "dist",
      sourcemap: true,
      rollupOptions: {
        preserveEntrySignatures: "strict",
        input: {
          discourse: "discourse.js",
          vendor: "vendor.js",
          "start-discourse": "start-discourse.js",
          "media-optimization-bundle": "media-optimization-bundle.js",
          ...(shouldBuildTests(mode)
            ? { tests: "tests/index.html" }
            : undefined),
        },
        output: {
          hashCharacters: "base36",
          assetFileNames: "assets/[name]-[hash].digested[extname]",
          chunkFileNames: "assets/[name]-[hash].digested.js",
          entryFileNames: "assets/[name]-[hash].digested.js",
          // manualChunks(id, { getModuleInfo }) {
          //   if (id.includes("node_modules")) {
          //     return "vendor";
          //   }
          // },
        },
      },
    },
    clearScreen: false,
    css: {
      preprocessorOptions: {
        scss: {
          loadPaths: ["../../stylesheets"],
        },
      },
    },
  };
});

function shouldBuildTests(mode) {
  return mode !== "production" || process.env.FORCE_BUILD_TESTS;
}
