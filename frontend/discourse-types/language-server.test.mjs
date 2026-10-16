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
