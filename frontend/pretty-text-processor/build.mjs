import { rolldown } from "rolldown";
import { importGlobPlugin, viteAliasPlugin } from "rolldown/experimental";

const FRONTEND = new URL("../", import.meta.url).pathname;
const SHIM = (f) => new URL(`./shims/${f}`, import.meta.url).pathname;

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
        { find: /^discourse\//, replacement: `${FRONTEND}discourse/app/` },
      ],
    }),
  ],
  resolve: { extensions: [".js", ".mjs", ".cjs", ".json"] },
});

const { output } = await bundle.generate({
  format: "iife",
  minify: false,
});

await bundle.close();
process.stdout.write(output[0].code);
