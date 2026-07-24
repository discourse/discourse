import BabelTransformTypescript from "@babel/plugin-transform-typescript";
import BabelPresetEnv from "@babel/preset-env";
import { rollup } from "@rollup/browser";
import { babel, getBabelOutputPlugin } from "@rollup/plugin-babel";
import HTMLBarsInlinePrecompile from "babel-plugin-ember-template-compilation";
import DecoratorTransforms from "decorator-transforms";
import colocatedBabelPlugin from "ember-cli-htmlbars/lib/colocated-babel-plugin";
import { precompile } from "ember-source/ember-template-compiler/index.js";
import EmberThisFallback from "ember-this-fallback";
import StripTestSelectorsPlugin from "strip-test-selectors/src/strip-test-selectors";
import { browsers } from "../discourse/config/targets";
import babelTransformModuleRenames from "../discourse/lib/babel-transform-module-renames";
import AddThemeGlobals from "./add-theme-globals";
import BabelResolveCoreImports from "./babel-resolve-core-imports";
import BabelResolvePluginImports from "./babel-resolve-plugin-imports";
import discourseColocation from "./rollup-plugins/discourse-colocation";
import discourseExternalLoader from "./rollup-plugins/discourse-external-loader";
import discourseFileSearch from "./rollup-plugins/discourse-file-search";
import discourseGjs from "./rollup-plugins/discourse-gjs";
import discourseHbs from "./rollup-plugins/discourse-hbs";
import discourseTerser from "./rollup-plugins/discourse-terser";
import discourseVirtualLoader from "./rollup-plugins/discourse-virtual-loader";
import buildEmberTemplateManipulatorPlugin from "./theme-hbs-ast-transforms";
import transformActionSyntax from "./transform-action-syntax";
import createVirtualFs from "./virtual-fs";

let lastRollupResult;
let lastRollupError;

let caches = new Map();

async function performRollup(modules, opts) {
  let basePath = opts.pluginName
    ? `discourse/plugins/${opts.pluginName}/`
    : `theme-${opts.themeId}/`;

  const inputConfig = {};

  for (const key of Object.keys(opts.entrypoints)) {
    inputConfig[key] = `virtual:entrypoint:${key}`;
  }

  const fs = createVirtualFs(modules, basePath);

  const cache = opts.pluginName ? caches.get(opts.pluginName) : false;

  const result = await rollup({
    input: inputConfig,
    logLevel: "info",
    fs,
    cache,
    onLog(level, message) {
      if (String(message).startsWith("Circular dependency")) {
        return;
      }
      // eslint-disable-next-line no-console
      console.info(level, message);
    },
    plugins: [
      discourseFileSearch(),
      discourseVirtualLoader({
        isTheme: !!opts.themeId,
        basePath,
        entrypoints: opts.entrypoints,
        opts,
      }),
      discourseExternalLoader({ basePath }),
      discourseColocation({ basePath }),
      getBabelOutputPlugin({
        plugins: [BabelResolveCoreImports, BabelResolvePluginImports],
        compact: false,
      }),
      babel({
        extensions: [".js", ".gjs", ".ts", ".gts", ".hbs"],
        babelHelpers: "bundled",
        compact: false,
        // Support `import ... with { ... }` for cross-plugin imports
        parserOpts: { plugins: ["importAttributes"] },
        overrides: [
          {
            test: /\.(gts|ts|mts|cts)$/,
            plugins: [[BabelTransformTypescript, { allowDeclareFields: true }]],
          },
        ],
        plugins: [
          [DecoratorTransforms, { runEarly: true }],
          opts.themeId ? AddThemeGlobals : null,
          babelTransformModuleRenames,
          colocatedBabelPlugin,
          [
            HTMLBarsInlinePrecompile,
            {
              compiler: { precompile },
              enableLegacyModules: [
                "ember-cli-htmlbars",
                "ember-cli-htmlbars-inline-precompile",
                "htmlbars-inline-precompile",
              ],
              transforms: [
                EmberThisFallback._buildPlugin({
                  enableLogging: false,
                  isTheme: true,
                }).plugin,
                buildEmberTemplateManipulatorPlugin(opts.themeId),
                transformActionSyntax,
                ...(opts.minify ? [StripTestSelectorsPlugin] : []),
              ],
            },
          ],
        ].filter(Boolean),
        presets: [
          [
            BabelPresetEnv,
            {
              modules: false,
              targets: { browsers },
            },
          ],
        ],
      }),
      discourseHbs(),
      discourseGjs(),
      discourseTerser({ opts }),
    ],
  });

  const bundle = await result.generate({
    format: "es",
    sourcemap: "hidden",
    importAttributesKey: "with",
    entryFileNames: `${opts.filenamePrefix ?? ""}[name].[hash:6]${opts.filenameSuffix ?? ""}.js`,
    chunkFileNames: `${opts.filenamePrefix ?? ""}chunk.[hash:6]${opts.filenameSuffix ?? ""}.js`,
  });

  if (opts.pluginName) {
    caches.set(opts.pluginName, result.cache);
  }

  const externalPluginImports = [
    ...new Set(
      bundle.output
        .flatMap((c) => c.imports ?? [])
        .filter((i) => i.startsWith("discourse/plugins/"))
        .map((i) => i.split("/")[2])
    ),
  ];

  const routeVirtualPrefix = `${basePath}virtual:route:`;

  const routeNameByFile = {};
  for (const chunk of bundle.output) {
    if (chunk.facadeModuleId?.startsWith(routeVirtualPrefix)) {
      routeNameByFile[chunk.fileName] = chunk.facadeModuleId.slice(
        routeVirtualPrefix.length
      );
    }
  }

  // Ties each lazy route chunk back to the route it was split at, so Ruby can preload it on a
  // direct navigation to that route's URL. The `import()` calls live in the entrypoint's own
  // module, which rollup is free to hoist into a shared chunk — so find the chunk that module
  // actually landed in rather than assuming it is the entry chunk. Doing this per entrypoint
  // keeps an admin route chunk from being attributed to `main`.
  function routeBundlesForEntry(entryName) {
    const entrypointModuleId = `${basePath}virtual:entrypoint:${entryName}`;

    const owner = bundle.output.find((chunk) =>
      chunk.moduleIds?.includes(entrypointModuleId)
    );

    const routeBundles = {};

    for (const fileName of owner?.dynamicImports ?? []) {
      if (routeNameByFile[fileName]) {
        routeBundles[routeNameByFile[fileName]] = fileName;
      }
    }

    return routeBundles;
  }

  const chunks = Object.fromEntries(
    bundle.output
      .filter((c) => c.code)
      .map((chunk) => {
        return [
          chunk.fileName,
          {
            code: chunk.code,
            map: JSON.stringify(chunk.map),
            name: chunk.name,
            isEntry: chunk.isEntry,
            imports: chunk.imports.filter((i) =>
              bundle.output.find((c) => c.fileName === i)
            ),
            routeBundles: chunk.isEntry
              ? routeBundlesForEntry(chunk.name)
              : undefined,
            externalPluginImports,
          },
        ];
      })
  );

  return chunks;
}

globalThis.rollup = async function (modules, opts) {
  try {
    lastRollupResult = await performRollup(modules, opts);
  } catch (error) {
    lastRollupError = error;
  }
};

globalThis.getRollupResult = function () {
  const error = lastRollupError;
  const result = lastRollupResult;

  lastRollupError = lastRollupResult = null;

  if (error) {
    throw error;
  }
  return result;
};
