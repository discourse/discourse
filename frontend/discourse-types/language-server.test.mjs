import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { once } from "node:events";
import { dirname, join, resolve } from "node:path";
import { test } from "node:test";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = resolve(import.meta.dirname, "../..");
const TSC = join(
  dirname(fileURLToPath(import.meta.resolve("typescript/package.json"))),
  "bin/tsc"
);
const PROBE_URI = fileUri(
  "plugins/chat/assets/javascripts/discourse/language-server-probe.ts"
);

// Each binding must resolve to its core source file through the project reference.
const IMPORTS = [
  {
    specifier: "discourse/lib/later",
    binding: "* as later",
    name: "later",
    source: "frontend/discourse/app/lib/later.ts",
  },
  {
    specifier: "discourse/lib/ajax",
    binding: "{ ajax }",
    name: "ajax",
    source: "frontend/discourse/app/lib/ajax.js",
  },
  {
    specifier: "discourse/ui-kit/d-button",
    binding: "DButton",
    name: "DButton",
    source: "frontend/discourse/app/ui-kit/d-button.gts",
  },
  {
    specifier: "discourse/components/pinned-button",
    binding: "PinnedButton",
    name: "PinnedButton",
    source: "frontend/discourse/app/components/pinned-button.gjs",
  },
];

const PROBE_LINES = [
  ...IMPORTS.map(
    ({ specifier, binding }) => `import ${binding} from "${specifier}";`
  ),
  `export const probe = [${IMPORTS.map(({ name }) => name).join(", ")}];`,
];

function fileUri(path) {
  return pathToFileURL(join(ROOT, path)).href;
}

class LanguageServer {
  #nextId = 0;
  #pending = new Map();
  #buffer = Buffer.alloc(0);
  #stderr = "";
  #process;

  constructor() {
    this.#process = spawn(process.execPath, [TSC, "--lsp", "--stdio"], {
      cwd: ROOT,
    });
    this.#process.stdout.on("data", (chunk) => this.#receive(chunk));
    this.#process.stderr.on("data", (chunk) => (this.#stderr += chunk));
    this.#process.stdin.on("error", (error) => this.#fail(error.message));
    this.#process.on("exit", (code) => this.#fail(`exited with ${code}`));
  }

  request(method, params) {
    const id = ++this.#nextId;
    const response = new Promise((resolvePromise, reject) =>
      this.#pending.set(id, { resolve: resolvePromise, reject })
    );
    this.#write({ id, method, params });
    return response;
  }

  notify(method, params) {
    this.#write({ method, params });
  }

  async close() {
    if (this.#process.exitCode === null) {
      this.#process.kill();
      await once(this.#process, "exit");
    }
  }

  #write(message) {
    const body = JSON.stringify({ jsonrpc: "2.0", ...message });
    this.#process.stdin.write(
      `Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`
    );
  }

  #receive(chunk) {
    this.#buffer = Buffer.concat([this.#buffer, chunk]);

    for (;;) {
      const headerEnd = this.#buffer.indexOf("\r\n\r\n");
      if (headerEnd === -1) {
        return;
      }
      const header = this.#buffer.subarray(0, headerEnd).toString();
      const length = Number(/Content-Length: (\d+)/i.exec(header)[1]);
      const bodyStart = headerEnd + 4;
      if (this.#buffer.length < bodyStart + length) {
        return;
      }
      const body = this.#buffer.subarray(bodyStart, bodyStart + length);
      this.#buffer = this.#buffer.subarray(bodyStart + length);
      this.#handle(JSON.parse(body.toString()));
    }
  }

  #handle(message) {
    if (message.method) {
      // The server waits for an answer to its own requests.
      if (message.id !== undefined) {
        this.#write({ id: message.id, result: null });
      }
      return;
    }

    const pending = this.#pending.get(message.id);
    this.#pending.delete(message.id);
    if (message.error) {
      pending?.reject(new Error(message.error.message));
    } else {
      pending?.resolve(message.result);
    }
  }

  #fail(reason) {
    const error = new Error(`Language server ${reason}\n${this.#stderr}`);
    for (const { reject } of this.#pending.values()) {
      reject(error);
    }
    this.#pending.clear();
  }
}

test("the language server resolves core imports from a plugin to core source", async (t) => {
  const server = new LanguageServer();
  t.after(() => server.close());

  await server.request("initialize", {
    processId: process.pid,
    rootUri: pathToFileURL(ROOT).href,
    capabilities: {},
    initializationOptions: { runExternalCode: true },
  });
  server.notify("initialized", {});
  server.notify("textDocument/didOpen", {
    textDocument: {
      uri: PROBE_URI,
      languageId: "typescript",
      version: 1,
      text: PROBE_LINES.join("\n") + "\n",
    },
  });

  for (const [line, { name, source }] of IMPORTS.entries()) {
    const result = await server.request("textDocument/definition", {
      textDocument: { uri: PROBE_URI },
      position: { line, character: PROBE_LINES[line].indexOf(name) },
    });
    const uris = [result ?? []]
      .flat()
      .map((location) => location.targetUri ?? location.uri);
    assert.deepEqual(uris, [fileUri(source)], name);
  }

  const diagnostics = await server.request("textDocument/diagnostic", {
    textDocument: { uri: PROBE_URI },
  });
  assert.deepEqual(diagnostics.items, []);
});

const REGISTRY_DIR = "plugins/chat/assets/javascripts/discourse";

const REGISTRY_AUGMENT = {
  uri: fileUri(`${REGISTRY_DIR}/registry-probe-augment.ts`),
  languageId: "typescript",
  lines: [
    `declare module "discourse/lib/transformer" {`,
    `  interface ValueTransformerRegistry {`,
    `    "probe-typed": { value: string[]; context: { id: number }; mutable: false };`,
    `  }`,
    `}`,
    `export {};`,
  ],
};

const REGISTRY_JS = {
  uri: fileUri(`${REGISTRY_DIR}/registry-probe.js`),
  languageId: "javascript",
  lines: [
    `import { withPluginApi } from "discourse/lib/plugin-api";`,
    `import { applyValueTransformer } from "discourse/lib/transformer";`,
    `withPluginApi((api) => {`,
    `  api.registerValueTransformer("", () => {});`,
    `  api.registerBehaviorTransformer("", () => {});`,
    `  api.registerValueTransformer("probe-typed", ({ value, context }) => [...value, String(context.id)]);`,
    `  api.registerValueTransformer("plugin-only", ({ value }) => value);`,
    `});`,
    `export const probe = applyValueTransformer("", 1);`,
  ],
};

const REGISTRY_TS = {
  uri: fileUri(`${REGISTRY_DIR}/registry-probe-check.ts`),
  languageId: "typescript",
  lines: [
    `import { applyValueTransformer } from "discourse/lib/transformer";`,
    `export const ok = applyValueTransformer("probe-typed", ["a"], { id: 1 });`,
    `export const bad = applyValueTransformer("probe-typed", 42, { id: 1 });`,
  ],
};

function open(server, { uri, languageId, lines }) {
  server.notify("textDocument/didOpen", {
    textDocument: {
      uri,
      languageId,
      version: 1,
      text: lines.join("\n") + "\n",
    },
  });
}

/** Position just inside the first `""` on a probe line. */
function insideEmptyString({ lines }, line) {
  return { line, character: lines[line].indexOf('""') + 1 };
}

async function completionLabels(server, file, line) {
  const result = await server.request("textDocument/completion", {
    textDocument: { uri: file.uri },
    position: insideEmptyString(file, line),
  });
  return (Array.isArray(result) ? result : (result?.items ?? [])).map(
    (item) => item.label
  );
}

async function hoverText(server, file, line, word) {
  const result = await server.request("textDocument/hover", {
    textDocument: { uri: file.uri },
    position: { line, character: file.lines[line].indexOf(word) },
  });
  const contents = result?.contents;
  return typeof contents === "string" ? contents : (contents?.value ?? "");
}

test("the transformer registry types hook names and callbacks for plugins", async (t) => {
  const server = new LanguageServer();
  t.after(() => server.close());

  await server.request("initialize", {
    processId: process.pid,
    rootUri: pathToFileURL(ROOT).href,
    capabilities: {},
    initializationOptions: { runExternalCode: true },
  });
  server.notify("initialized", {});
  open(server, REGISTRY_AUGMENT);
  open(server, REGISTRY_JS);
  open(server, REGISTRY_TS);

  const valueRegistration = await completionLabels(server, REGISTRY_JS, 3);
  assert.ok(valueRegistration.includes("topic-list-item-class"));
  assert.ok(valueRegistration.includes("probe-typed"));
  assert.ok(!valueRegistration.includes("create-account"));

  const behaviorRegistration = await completionLabels(server, REGISTRY_JS, 4);
  assert.ok(behaviorRegistration.includes("create-account"));
  assert.ok(!behaviorRegistration.includes("topic-list-item-class"));

  const valueApply = await completionLabels(server, REGISTRY_JS, 8);
  assert.ok(valueApply.includes("topic-list-item-class"));

  assert.match(
    await hoverText(server, REGISTRY_JS, 5, "value"),
    /value: string\[\]/
  );
  assert.match(
    await hoverText(server, REGISTRY_JS, 5, "context"),
    /context: \{\s*id: number;?\s*\}/
  );
  assert.match(
    await hoverText(server, REGISTRY_JS, 6, "value"),
    /value: unknown/
  );

  const jsDiagnostics = await server.request("textDocument/diagnostic", {
    textDocument: { uri: REGISTRY_JS.uri },
  });
  assert.deepEqual(
    jsDiagnostics.items.filter((item) => item.severity === 1),
    []
  );

  const tsDiagnostics = await server.request("textDocument/diagnostic", {
    textDocument: { uri: REGISTRY_TS.uri },
  });
  assert.deepEqual(
    tsDiagnostics.items
      .filter((item) => item.severity === 1)
      .map((item) => item.range.start.line),
    [2]
  );
});
