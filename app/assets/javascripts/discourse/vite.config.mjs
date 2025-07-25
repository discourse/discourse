import {
  assets,
  compatPrebuild,
  contentFor,
  ember,
  hbs,
  optimizeDeps,
  resolver,
  scripts,
  templateTag,
} from "@embroider/vite";
import { babel } from "@rollup/plugin-babel";
import basicSsl from "@vitejs/plugin-basic-ssl";
import { visualizer } from "rollup-plugin-visualizer";
import { defineConfig } from "vite";
import mkcert from "vite-plugin-mkcert";
import customProxy from "../custom-proxy";
import customInvokableResolver from "./lib/custom-invokable-resolver";
import discourseTestSiteSettings from "./lib/site-settings-plugin";

const extensions = [
  ".mjs",
  ".gjs",
  ".js",
  ".mts",
  ".gts",
  ".ts",
  ".hbs",
  ".json",
];

export default defineConfig(({ mode, command }) => {
  return {
    base: command === "build" ? "" : "/@vite/",
    resolve: {
      extensions,
      alias: [
        { find: "pretty-text", replacement: "/../pretty-text/addon" },
        {
          find: "discourse-widget-hbs",
          replacement: "/../discourse-widget-hbs/addon",
        },
        { find: "select-kit", replacement: "/../select-kit/addon" },
        { find: "float-kit", replacement: "/../float-kit/addon" },
        { find: "discourse/tests", replacement: "/tests" },
        { find: "discourse", replacement: "/app" },
        { find: "admin", replacement: "/../admin/addon" },
        { find: "dialog-holder", replacement: "/../dialog-holder/addon" },
      ],
    },
    plugins: [
      // Standard Ember stuff
      ember(),
      hbs(),
      scripts(),
      compatPrebuild(),
      assets(),
      contentFor(),

      discourseTestSiteSettings(),
      customInvokableResolver(),

      babel({
        babelHelpers: "runtime",
        extensions,
      }),

      // Discourse-specific
      // viteProxy(),
      // mkcert(),
      visualizer({ emitFile: true }),
    ],
    optimizeDeps: {
      ...optimizeDeps(),
      include: ["virtual-dom"],
    },
    server: {
      port: 4200,
      strictPort: true,

      proxy: {
        "^/(?!@vite/)": customProxy,
      },
      // https: {
      //   maxSessionMemory: 1000,
      // },
    },
    preview: {
      port: 4200,
      strictPort: true,
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
