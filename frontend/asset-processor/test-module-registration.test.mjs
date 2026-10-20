import { rollup } from "@rollup/browser";
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { runInNewContext } from "node:vm";
import { rolldown } from "rolldown";
import { viteImportGlobPlugin } from "rolldown/experimental";
import {
  afterAll,
  afterEach,
  beforeAll,
  describe,
  expect,
  it,
  vi,
} from "vitest";
import wrapTestModulesPlugin from "../discourse/lib/wrap-test-modules-plugin.mjs";
import discourseFileSearch from "./rollup-plugins/discourse-file-search.js";
import discourseVirtualLoader from "./rollup-plugins/discourse-virtual-loader.js";
import discourseWrapTestModules, {
  testModuleIdsFor,
} from "./rollup-plugins/discourse-wrap-test-modules.js";
import createVirtualFs from "./virtual-fs.js";

const require = createRequire(
  new URL("../discourse/package.json", import.meta.url)
);
const loaderPath =
  require.resolve("ember-exam/addon-test-support/-private/ember-exam-test-loader.js");
const basePath = "discourse/plugins/example/";
const roots = [];

beforeAll(() => {
  // The browser bundler fetches its WASM parser; Node cannot fetch file URLs.
  vi.stubGlobal(
    "fetch",
    (url) =>
      new Response(readFileSync(url), {
        headers: { "Content-Type": "application/wasm" },
      })
  );
});

afterAll(() => vi.unstubAllGlobals());

afterEach(() => {
  for (const root of roots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

async function pluginBundle(modules) {
  const entrypoints = { test: { modules: Object.keys(modules) } };
  const bundle = await rollup({
    input: "virtual:entrypoint:test",
    fs: createVirtualFs(modules, basePath),
    plugins: [
      discourseFileSearch(),
      discourseVirtualLoader({ basePath, entrypoints, opts: {} }),
      discourseWrapTestModules({
        testModuleIds: testModuleIdsFor(basePath, entrypoints.test.modules),
      }),
    ],
  });
  try {
    const { output } = await bundle.generate({ format: "es" });
    return output[0].code;
  } finally {
    await bundle.close();
  }
}

const fixtures = {
  "unit/first-test.js": 'globalThis.registered.push("first");',
  "unit/second-test.js": 'globalThis.registered.push("second");',
  "acceptance/third-test.js": 'globalThis.registered.push("third");',
  "helpers/example.js": "export const example = true;",
};

// Exercise the real boot and selection code while replacing browser/application setup.
async function bootBundle(
  modules = fixtures,
  coreCode = 'await Promise.resolve(); globalThis.registered.push("core");'
) {
  const directory = mkdtempSync(join(tmpdir(), "test-registration-"));
  roots.push(directory);
  const root = join(directory, "tests");
  mkdirSync(root);
  writeFileSync(join(root, "plugin.js"), await pluginBundle(modules));
  writeFileSync(join(root, "core-test.js"), coreCode);
  writeFileSync(
    join(root, "boot.js"),
    readFileSync(
      new URL("../discourse/tests/test-boot-ember-cli.js", import.meta.url),
      "utf8"
    )
  );
  writeFileSync(
    join(root, "entry.js"),
    `import modules from "./plugin.js";
     globalThis.requirejs = (name) => requirejs.entries[name];
     requirejs.entries = Object.fromEntries(
       Object.entries(modules).map(([name, value]) => [${JSON.stringify(basePath)} + name, value])
     );
     requirejs.entries[${JSON.stringify(`${basePath}discourse/lib/connection-test`)}] = {
       default() { throw new Error("Application module mistaken for a test"); }
     };
     export { startTests } from "./boot.js";`
  );

  const stubs = {
    "ember-exam/addon-test-support": `
      import Loader from ${JSON.stringify(loaderPath)};
      export function start(options) {
        globalThis.examOptions = options;
        const loader = new Loader(null, new Map(new URLSearchParams(window.location.search)));
        globalThis.registration = loader.loadModules(options);
        return globalThis.registration;
      }`,
    "ember-qunit": "export function setupEmberOnerrorValidation() {}",
    "ember-qunit/test-loader": `export class TestLoader {
      loadModules() { globalThis.usedLegacyLoader = true; }
    }`,
    "@ember/debug": `export function assert(message, condition) {
      if (!condition) { throw new Error(message); }
    }`,
    qunit: `export const assert = {};
      export const config = { seed: "fixed" };
      export default { testDone() {} };`,
    "qunit-dom": "export function setup() {}",
    "discourse/app": `export async function loadAdmin() {}
      export async function loadThemesAndPlugins() {}`,
    "discourse/config/environment": "export default { APP: {} };",
    "discourse/tests/setup-tests": "export default async function () {}",
  };

  const bundle = await rolldown({
    input: join(root, "entry.js"),
    experimental: { nativeMagicString: true },
    plugins: [
      {
        name: "test-environment",
        resolveId(source) {
          if (Object.hasOwn(stubs, source)) {
            return `\0${source}`;
          }
        },
        load(id) {
          return stubs[id.slice(1)];
        },
      },
      viteImportGlobPlugin(),
      wrapTestModulesPlugin(),
    ],
  });
  try {
    const { output } = await bundle.generate({ format: "cjs" });
    return output[0].code;
  } finally {
    await bundle.close();
  }
}

async function runBoot(
  code,
  { target = "example", filePath, theme = false } = {}
) {
  const query = new URLSearchParams({ target });
  if (filePath) {
    query.set("filePath", filePath);
  }
  const runtime = {
    exports: {},
    registered: theme ? ["theme"] : [],
    URLSearchParams,
    window: { location: { search: `?${query}` } },
    document: {
      getElementById() {},
      querySelector: () =>
        theme ? { dataset: { themeName: "Example" } } : null,
      body: { insertAdjacentHTML() {} },
      fonts: { async load() {}, ready: Promise.resolve() },
    },
    getComputedStyle: () => ({}),
  };
  runInNewContext(code, runtime);
  expect(runtime.registered).toEqual(theme ? ["theme"] : []);
  await runtime.exports.startTests();
  await runtime.registration;
  return runtime;
}

describe("test module registration", () => {
  it("registers only the selected plugin file", async () => {
    const runtime = await runBoot(await bootBundle(), {
      filePath: `${basePath}unit/first-test.js`,
    });
    expect(runtime.registered).toEqual(["first"]);
  });

  it("registers only files in the selected plugin directory", async () => {
    const runtime = await runBoot(await bootBundle(), {
      filePath: `${basePath}unit/`,
    });
    expect(runtime.registered).toEqual(["first", "second"]);
  });

  it("registers all plugin tests without a file filter", async () => {
    const runtime = await runBoot(await bootBundle());
    expect(runtime.registered).toEqual(["first", "second", "third"]);
    expect(Object.keys(runtime.examOptions.availableModules)).toHaveLength(3);
  });

  it("awaits asynchronous registration only for the selected plugin file", async () => {
    const code = await bootBundle({
      "unit/first-test.js":
        'await Promise.resolve(); globalThis.registered.push("async");',
      "unit/second-test.js": 'throw new Error("Unselected file ran");',
    });
    const runtime = await runBoot(code, {
      filePath: `${basePath}unit/first-test.js`,
    });
    expect(runtime.registered).toEqual(["async"]);
  });

  it("rejects exported plugin tests during compilation", async () => {
    await expect(
      pluginBundle({ "unit/exported-test.js": "export const helper = true;" })
    ).rejects.toThrow(
      /Test modules cannot contain exports.*separate helper module/
    );
  });

  it("registers core tests without registering plugin tests", async () => {
    const runtime = await runBoot(await bootBundle(), { target: "core" });
    expect(runtime.registered).toEqual(["core"]);
  });

  it("rejects exported core tests during compilation", async () => {
    await expect(
      bootBundle(fixtures, "export default function helper() {}")
    ).rejects.toThrow(
      /Test modules cannot contain exports.*separate helper module/
    );
  });

  it("keeps the legacy theme loader without registering core or plugin tests", async () => {
    const runtime = await runBoot(await bootBundle(), { theme: true });
    expect(runtime.examOptions.availableModules).toBeUndefined();
    expect(runtime.usedLegacyLoader).toBe(true);
    expect(runtime.registered).toEqual(["theme"]);
  });
});
