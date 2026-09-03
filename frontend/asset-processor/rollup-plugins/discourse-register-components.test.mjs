import { parseAst } from "rolldown/parseAst";
import { describe, expect, it } from "vitest";
import discourseRegisterComponents from "./discourse-register-components";

const basePath = "discourse/plugins/chat/";

// Stands in for the `this` a transform hook gets.
const context = { parse: parseAst };

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

  it("registers a component wherever the plugin nests it", () => {
    // The resolver finds `components/<name>` as a path suffix at any depth, so a plugin is free
    // to keep them at the root or below an `app/` directory.
    expect(
      transform(`export default class A {}`, "components/survey.gjs")
    ).toContain(`"survey"`);
    expect(
      transform(
        `export default class A {}`,
        "discourse/app/components/panel.gjs"
      )
    ).toContain(`"panel"`);
  });

  it("leaves everything that is not a component alone", () => {
    expect(
      transform(`export default class A {}`, "discourse/routes/chat/channel.js")
    ).toBe(null);
    expect(
      transform(`export const a = 1;`, "discourse/components/no-default.js")
    ).toBe(null);
  });

  it("leaves classic component templates alone", () => {
    // The resolver's suffix trie skips anything under `templates/`, and these compile to a
    // template factory rather than a component class.
    expect(
      transform(
        `export default class A {}`,
        "discourse/templates/components/legacy.hbs"
      )
    ).toBe(null);
    expect(
      transform(
        `export default class A {}`,
        "discourse/templates/foo/components/bar.hbs"
      )
    ).toBe(null);
  });
});
