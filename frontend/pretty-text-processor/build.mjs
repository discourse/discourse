import { rolldown } from "rolldown";
import { importGlobPlugin, viteAliasPlugin } from "rolldown/experimental";

const FRONTEND = new URL("../", import.meta.url).pathname;
const SHIM = (f) => new URL(`./shims/${f}`, import.meta.url).pathname;

// Allowlist of bundleable `discourse` core modules, supplied by
// PrettyText::BUNDLED_DISCOURSE_MODULES in lib/pretty_text.rb.
const DISCOURSE_MODULES = process.argv
  .find((arg) => arg.startsWith("--discourse-modules="))
  ?.slice("--discourse-modules=".length)
  .split(",");

if (!DISCOURSE_MODULES?.length) {
  throw new Error(
    "Missing --discourse-modules=<comma-separated list> (see lib/pretty_text.rb)"
  );
}

const bundle = await rolldown({
  input: new URL("./entry.js", import.meta.url).pathname,
  platform: "browser",
  plugins: [
    importGlobPlugin(),
    viteAliasPlugin({
      entries: [
        { find: "discourse-i18n", replacement: SHIM("i18n.js") },
        { find: "discourse/lib/helpers", replacement: SHIM("helpers.js") },
        {
          find: "discourse/lib/deprecated",
          replacement: SHIM("deprecated.js"),
        },
        ...DISCOURSE_MODULES.map((m) => ({
          find: `discourse/${m}`,
          replacement: `${FRONTEND}discourse/app/${m}.js`,
        })),
        {
          find: /^pretty-text\//,
          replacement: `${FRONTEND}pretty-text/addon/`,
        },
      ],
    }),
    {
      // The `discourse` package's exports map would resolve anything under
      // discourse/*; only imports rewritten by the aliases above are allowed.
      name: "discourse-import-allowlist",
      resolveId(id, importer) {
        if (id.startsWith("discourse/")) {
          throw new Error(
            `"${id}" (imported by ${importer}) is not in PrettyText::BUNDLED_DISCOURSE_MODULES`
          );
        }
      },
    },
  ],
  resolve: { extensions: [".js", ".mjs", ".cjs", ".json"] },
});

const { output } = await bundle.generate({
  format: "iife",
  minify: false,
});

await bundle.close();
process.stdout.write(output[0].code);
