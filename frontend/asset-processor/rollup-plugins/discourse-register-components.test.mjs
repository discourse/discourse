import fs from "node:fs";
import { describe, expect, it } from "vitest";
import discourseRegisterComponents from "./discourse-register-components";

const basePath = "discourse/plugins/chat/";

// Stands in for the `this` a transform hook gets. `@rollup/browser` fetches its wasm parser,
// which node cannot do for a file url; the asset processor bundle inlines it instead.
const realFetch = globalThis.fetch;
globalThis.fetch = async (url) => {
  const target = url instanceof URL ? url : new URL(url);
  if (target.protocol === "file:") {
    return new Response(fs.readFileSync(target));
  }
  return realFetch(url);
};

const { rollup } = await import("@rollup/browser");

let context;
await rollup({
  input: "entry",
  plugins: [
    {
      name: "capture-parse",
      resolveId: (id) => id,
      load: () => "export default 1",
      buildStart() {
        context = { parse: (code) => this.parse(code) };
      },
    },
  ],
});

function transform(code, file) {
  const { handler } = discourseRegisterComponents({ basePath }).transform;
  return handler.call(context, code, `${basePath}${file}`)?.code ?? null;
}

describe("discourse-register-components", () => {
  it("registers a named default class under its resolver path", () => {
    const out = transform(
      `export default class ChatHeader {}`,
      "discourse/components/chat-header.gjs"
    );

    expect(out).toContain(
      `registerModuleForModifyClass("chat-header", ChatHeader);`
    );
    expect(out).toContain(`export default class ChatHeader {}`);
  });

  it("gives an anonymous default export a binding to register", () => {
    const out = transform(
      `import Component from "@glimmer/component";\nexport default class extends Component {}`,
      "discourse/components/chat-header.gjs"
    );

    expect(out).toContain(`const __discourseComponentClass = class extends`);
    expect(out).toContain(`export default __discourseComponentClass;`);
    expect(out).toContain(
      `registerModuleForModifyClass("chat-header", __discourseComponentClass);`
    );
  });

  it("handles a default export that is just an identifier", () => {
    const out = transform(
      `const Old = 1;\nexport default Old;`,
      "discourse/components/old-title.gjs"
    );

    expect(out).toContain(`registerModuleForModifyClass("old-title", Old);`);
  });

  it("uses the nested path, and drops an index segment", () => {
    expect(
      transform(
        `export default class A {}`,
        "discourse/components/chat/header/icon.gjs"
      )
    ).toContain(`"chat/header/icon"`);

    expect(
      transform(
        `export default class A {}`,
        "discourse/components/channel-icon/index.gjs"
      )
    ).toContain(`"channel-icon"`);
  });

  it("leaves everything that is not a component alone", () => {
    expect(
      transform(`export default class A {}`, "discourse/routes/chat/channel.js")
    ).toBe(null);
    expect(
      transform(
        `export default class A {}`,
        "discourse/routes/chat/components/thing.js"
      )
    ).toBe(null);
    expect(
      transform(`export const a = 1;`, "discourse/components/no-default.js")
    ).toBe(null);
  });
});
