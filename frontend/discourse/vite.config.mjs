import {
  assets,
  classicEmberSupport,
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
import { readPackageUpSync } from "read-package-up";
import { dirname } from "node:path";

const extensions = [
  ".gjs",
  ".mjs",
  ".js",
  ".mts",
  ".gts",
  ".ts",
  ".hbs",
  // ".json",
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
      ],
    },
    plugins: [
      // Standard Ember stuff
      ember({
        rolldownSharedPlugins: [
          // "rollup-hbs-plugin",
          // "embroider-template-tag",
          // "embroider-resolver",
          // "babel",
        ],
      }),

      classicEmberSupport(),
      // hbs(),
      // scripts(),
      // compatPrebuild(),
      // assets(),
      // contentFor(),

      discourseTestSiteSettings(),
      // customInvokableResolver(),

      babel({
        babelHelpers: "runtime",
        extensions,
        filter(id) {
          const x = !!readPackageUpSync({
            cwd: dirname(id),
          }).packageJson["ember-addon"];
          // console.log(x, id);
          return x;
        },
      }),

      // Discourse-specific
      // viteProxy(),
      // mkcert(),
      visualizer({ emitFile: true }),
    ],
    optimizeDeps: {
      rollupOptions: {
        plugins: [
          hbs(),
          templateTag(),
          resolver(),
          babel({
            babelHelpers: "runtime",
            extensions,
            filter(id) {
              const x = !!readPackageUpSync({
                cwd: dirname(id),
              }).packageJson["ember-addon"];
              console.log(x, id);
              return x;
            },
          }),
        ],
      },
    },
    // optimizeDeps: {
    //   ...optimizeDeps(),
    //   include: ["virtual-dom"],
    // },
    // optimizeDeps: {
    //   include: ["virtual-dom"],
    //   exclude: ["@embroider/macros"],
    //   rollupOptions: {
    //     plugins: [
    //       resolver(),
    //       templateTag(),
    //       babel({ babelHelpers: "runtime", extensions }),
    //     ],
    //   },
    // },
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
      proxy: {
        "^/(?!@vite/)": customProxy,
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
