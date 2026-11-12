/* eslint-disable qunit/require-expect */
import { mkdtempSync, realpathSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import { rolldown } from "rolldown";
import { expect, test } from "vitest";
import discourseSourceImports from "../discourse/lib/discourse-source-imports.mjs";

const EXAMPLE = `const label = "Save";

export default <template>
  <button type="button">
    {{label}}
  </button>
</template>;
`;

function build(modules = { "/app/example.gjs": EXAMPLE }) {
  // Stands in for node's fs.promises / the asset processor's virtual fs: reads
  // from the map and throws for a missing file, the way a real read would.
  const fs = {
    readFile(id) {
      if (!(id in modules)) {
        throw new Error(`ENOENT: no such file, open '${id}'`);
      }
      return modules[id];
    },
  };
  const plugin = discourseSourceImports({ fs });

  // Minimal stand-in for the rollup plugin context. `error` throws, matching
  // rollup, so tests can assert on the message.
  const context = {
    resolve: (source) =>
      source.startsWith("external:")
        ? { id: source, external: true }
        : { id: source, external: false },
    error(message) {
      throw new Error(message);
    },
    addWatchFile() {},
  };

  return {
    resolveId: (specifier) =>
      plugin.resolveId.handler.call(context, specifier, "/app/importer.js"),
    load: (id) => plugin.load.handler.call(context, id),
    filters: { resolveId: plugin.resolveId.filter, load: plugin.load.filter },
  };
}

async function sourceOf(specifier, modules) {
  const plugin = build(modules);
  const id = await plugin.resolveId(specifier);
  const code = await plugin.load(id);

  return JSON.parse(code.replace(/^export default /, "").replace(/;$/, ""));
}

test("?source=file returns the whole file, dedented", async () => {
  expect(await sourceOf("/app/example.gjs?source=file")).toBe(EXAMPLE.trim());
});

test("?source=template returns only the template contents", async () => {
  expect(await sourceOf("/app/example.gjs?source=template")).toBe(
    '<button type="button">\n  {{label}}\n</button>'
  );
});

test("?source=file works on a module with no template", async () => {
  const modules = { "/app/plain.js": "export const MAX = 50;\n" };

  expect(await sourceOf("/app/plain.js?source=file", modules)).toBe(
    "export const MAX = 50;"
  );
});

test("imports without a source query are left alone", async () => {
  expect(
    await build().resolveId("/app/example.gjs?other=?source=1")
  ).toBeNull();
});

test("the resolveId filter keeps every other module off the handler", () => {
  const { resolveId } = build().filters;

  // Every specifier the handler reports on has to reach it, including the ones it
  // rejects, so the value is left open and a bare `?source` still matches.
  expect(resolveId.id.test("/app/example.gjs?source=file")).toBe(true);
  expect(resolveId.id.test("/app/example.gjs?source=bogus")).toBe(true);
  expect(resolveId.id.test("/app/example.gjs?source")).toBe(true);
  expect(resolveId.id.test("/app/example.gjs?other=1&source=file")).toBe(true);

  expect(resolveId.id.test("/app/example.gjs")).toBe(false);
  expect(resolveId.id.test("/app/example.gjs?other=1")).toBe(false);
  expect(resolveId.id.test("/app/example.gjs?sourcemap=1")).toBe(false);
  expect(resolveId.id.test("/app/resource.gjs")).toBe(false);

  // A percent-encoded key parses back to `source`, but matching that costs every
  // module in the build a decode. A typo here fails as an unresolved import.
  expect(resolveId.id.test("/app/example.gjs?%73ource=file")).toBe(false);
});

test("rejects an unknown source value", async () => {
  await expect(
    build().resolveId("/app/example.gjs?source=bogus")
  ).rejects.toThrow(/single \?source= value/);
});

test("rejects a valueless source query", async () => {
  await expect(build().resolveId("/app/example.gjs?source")).rejects.toThrow(
    /single \?source= value/
  );
});

test("rejects duplicate source values rather than picking the first", async () => {
  await expect(
    build().resolveId("/app/example.gjs?source=file&source=template")
  ).rejects.toThrow(/single \?source= value/);
});

test("rejects an unrecognized query parameter alongside source", async () => {
  await expect(
    build().resolveId("/app/example.gjs?source=file&unknown")
  ).rejects.toThrow(/do not support the "unknown" query parameter/);
});

test("a module with no source of its own fails when read", async () => {
  const plugin = build();
  const id = await plugin.resolveId("/app/missing.gjs?source=file");

  await expect(plugin.load(id)).rejects.toThrow(/ENOENT/);
});

test("rejects an external module", async () => {
  await expect(
    build().resolveId("external:pkg/thing.js?source=file")
  ).rejects.toThrow(/Cannot import source from/);
});

function fixtureRoot() {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "source-imports-")));

  writeFileSync(join(root, "example.gjs"), EXAMPLE);

  return root;
}

async function bundleEntry(root, entry) {
  writeFileSync(join(root, "entry.js"), entry);

  const bundle = await rolldown({
    input: join(root, "entry.js"),
    plugins: [discourseSourceImports()],
  });

  const { output } = await bundle.generate({ format: "es" });

  return output[0].code;
}

// The tests above drive the handlers directly. This runs a real rolldown build the
// way core registers the plugin, so the hook filters, resolver re-entry, disk reads,
// and virtual loading are exercised together.
test("resolves both modes through a real rolldown build", async () => {
  const root = fixtureRoot();
  const code = await bundleEntry(
    root,
    `import whole from "./example.gjs?source=file";
     import template from "./example.gjs?source=template";
     export default [whole, template];
    `
  );

  const [whole, template] = JSON.parse(code.match(/(\[".*"\])/s)[1]);

  expect(whole).toBe(EXAMPLE.trim());
  expect(template).toBe('<button type="button">\n  {{label}}\n</button>');
});

test("?source=template requires exactly one template", async () => {
  const modules = {
    "/app/none.js": "export const value = 1;",
    "/app/two.gjs":
      "export const A = <template>a</template>;\nexport const B = <template>b</template>;",
  };

  for (const name of ["none.js", "two.gjs"]) {
    const plugin = build(modules);
    const id = await plugin.resolveId(`/app/${name}?source=template`);

    await expect(plugin.load(id)).rejects.toThrow(/exactly one template/);
  }
});
