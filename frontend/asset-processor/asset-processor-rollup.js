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
import discourseSourceImports from "../discourse/lib/discourse-source-imports.mjs";
import AddThemeGlobals from "./add-theme-globals";
import BabelResolveCoreImports from "./babel-resolve-core-imports";
import BabelResolvePluginImports from "./babel-resolve-plugin-imports";
import discourseColocation from "./rollup-plugins/discourse-colocation";
import discourseExternalLoader from "./rollup-plugins/discourse-external-loader";
import discourseFileSearch from "./rollup-plugins/discourse-file-search";
import discourseGjs from "./rollup-plugins/discourse-gjs";
import discourseHbs from "./rollup-plugins/discourse-hbs";
import discourseRegisterComponents from "./rollup-plugins/discourse-register-components";
import discourseRouteMaps from "./rollup-plugins/discourse-route-maps";
import discourseTerser from "./rollup-plugins/discourse-terser";
import discourseVirtualLoader from "./rollup-plugins/discourse-virtual-loader";
import { labelFor, routeNamesFor } from "./rollup-virtual-imports";
import { urlTableFor } from "./route-map-parser";
import buildEmberTemplateManipulatorPlugin from "./theme-hbs-ast-transforms";
import transformActionSyntax from "./transform-action-syntax";
import createVirtualFs from "./virtual-fs";

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

  // Filled in by `discourse-route-maps` before the entrypoint is generated from it.
  const routeTables = { bundleByRoute: {}, derived: [] };
  opts.routeTables = routeTables;

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
      discourseRouteMaps({
        modules,
        label: labelFor(opts),
        tables: routeTables,
        staticModules: !!opts.frontendConfig?.staticModules,
      }),
      discourseSourceImports({ fs }),
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
      discourseRegisterComponents({ basePath }),
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

  // Keyed by the qualified `<entrypoint>:<bundle>` from the module id, because two entrypoints
  // can each have a bundle of the same name.
  const bundleNameByFile = {};
  for (const chunk of bundle.output) {
    if (chunk.facadeModuleId?.startsWith(routeVirtualPrefix)) {
      bundleNameByFile[chunk.fileName] = chunk.facadeModuleId.slice(
        routeVirtualPrefix.length
      );
    }
  }

  // Rollup may hoist the entrypoint module into a shared chunk, so find where it landed.
  function routeBundlesForEntry(entryName) {
    const entrypointModuleId = `${basePath}virtual:entrypoint:${entryName}`;

    const owner = bundle.output.find((chunk) =>
      chunk.moduleIds?.includes(entrypointModuleId)
    );

    const fileNameByBundle = {};

    for (const fileName of owner?.dynamicImports ?? []) {
      const qualified = bundleNameByFile[fileName];

      if (qualified?.startsWith(`${entryName}:`)) {
        fileNameByBundle[qualified.slice(entryName.length + 1)] = fileName;
      }
    }

    // A bundle name means a different bundle in each entrypoint, so the urls have to come from
    // this entrypoint's own routes rather than from every route the plugin declares.
    const owned = routeNamesFor(
      opts.entrypoints[entryName].modules,
      opts,
      routeTables.bundleByRoute
    );
    const urls = urlTableFor(
      routeTables.derived.filter((route) => owned.has(route.name))
    );

    // Already ordered most specific first, which is the order Ruby matches them in.
    return urls
      .filter(({ bundleName }) => fileNameByBundle[bundleName])
      .map(({ bundleName, url }) => ({
        url,
        fileName: fileNameByBundle[bundleName],
      }));
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

globalThis.rollup = performRollup;
