/* eslint-disable qunit/require-expect */
import { Preprocessor } from "content-tag";
import {
  mkdirSync,
  mkdtempSync,
  realpathSync,
  symlinkSync,
  writeFileSync,
} from "fs";
import { tmpdir } from "os";
import { join } from "path";
import { rolldown } from "rolldown";
import { expect, test } from "vitest";
import discourseSourceImports from "../discourse/lib/discourse-source-imports.mjs";
import createDiskSourceReader from "../discourse/lib/disk-source-reader.mjs";

const preprocessor = new Preprocessor();

const EXAMPLE = `const label = "Save";

export default <template>
  <button type="button">
    {{label}}
  </button>
</template>;
`;

function build(modules = { "/app/example.gjs": EXAMPLE }) {
  const plugin = discourseSourceImports({
    preprocessor,
    readSource: (id) => modules[id],
  });

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
  const code = plugin.load(id);

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
  expect(await build().resolveId("/app/example.gjs?other=1")).toBeNull();
});

test("the resolveId filter is a superset of what the handler accepts", () => {
  const { resolveId } = build().filters;

  // Percent-encoded keys still parse as `source`, so the filter must not try to
  // match the key itself or they would bypass the handler's error.
  expect(resolveId.id.test("/app/example.gjs?%73ource=file")).toBe(true);
  expect(resolveId.id.test("/app/example.gjs?source=file")).toBe(true);
  expect(resolveId.id.test("/app/example.gjs")).toBe(false);
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

test("rejects a module with no source of its own", async () => {
  await expect(
    build().resolveId("/app/missing.gjs?source=file")
  ).rejects.toThrow(/Cannot import source from/);
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
    plugins: [
      discourseSourceImports({
        preprocessor,
        readSource: createDiskSourceReader(root),
      }),
    ],
  });

  const { output } = await bundle.generate({ format: "es" });

  return output[0].code;
}

// The tests above drive the handlers directly. These run a real rolldown build the
// way core registers the plugin, so the hook filters, resolver re-entry, disk reads,
// containment and virtual loading are exercised together.
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

test("refuses to inline a file outside the root", async () => {
  const root = fixtureRoot();
  const elsewhere = realpathSync(
    mkdtempSync(join(tmpdir(), "source-imports-out-"))
  );

  writeFileSync(join(elsewhere, "secret.txt"), "should never be inlined");

  await expect(
    bundleEntry(
      root,
      `import leaked from "${join(elsewhere, "secret.txt")}?source=file";
       export default leaked;
      `
    )
  ).rejects.toThrow(/Cannot import source from/);
});

test("refuses to follow a symlink pointing outside the root", async () => {
  const root = fixtureRoot();
  const elsewhere = realpathSync(
    mkdtempSync(join(tmpdir(), "source-imports-link-"))
  );

  writeFileSync(join(elsewhere, "secret.txt"), "should never be inlined");
  symlinkSync(join(elsewhere, "secret.txt"), join(root, "linked.txt"));

  await expect(
    bundleEntry(
      root,
      `import leaked from "./linked.txt?source=file";
       export default leaked;
      `
    )
  ).rejects.toThrow(/Cannot import source from/);
});

test("refuses to inline from node_modules", async () => {
  const root = fixtureRoot();

  mkdirSync(join(root, "node_modules", "pkg"), { recursive: true });
  writeFileSync(
    join(root, "node_modules", "pkg", "index.js"),
    "export default 1;"
  );

  await expect(
    bundleEntry(
      root,
      `import leaked from "./node_modules/pkg/index.js?source=file";
       export default leaked;
      `
    )
  ).rejects.toThrow(/Cannot import source from/);
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

    expect(() => plugin.load(id)).toThrow(/exactly one template/);
  }
});
