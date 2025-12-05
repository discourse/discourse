import { classicEmberSupport, ember } from "@embroider/vite";
import basicSsl from "@vitejs/plugin-basic-ssl";
import { visualizer } from "rollup-plugin-visualizer";
import { defineConfig } from "vite";
import mkcert from "vite-plugin-mkcert";
import customProxy from "../custom-proxy";
import writeResolverConfig from "./lib/embroider-vite-resolver-options";
import discourseTestSiteSettings from "./lib/site-settings-plugin";
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
  ];
  // }
  return {
    base: "",
    resolve: {
      extensions,
      alias: aliases,
    },
    plugins: [
      // Standard Ember stuff

      ember(),

      // classicEmberSupport(),

      discourseTestSiteSettings(),

      maybeBabel({
        babelHelpers: "runtime",
        extensions,
      }),

      // Discourse-specific
      // mkcert(),
      visualizer({ emitFile: true }),
    ],
    server: {
      port: 4200,
      strictPort: true,

      proxy: {
        "/": customProxy(),
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
      manifest: true,
      outDir: "dist",
      sourcemap: true,
      rollupOptions: {
        input: {
          discourse: "discourse.js",
          vendor: "vendor.js",
          "start-discourse": "start-discourse.js",
          // admin: "admin.js",
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
