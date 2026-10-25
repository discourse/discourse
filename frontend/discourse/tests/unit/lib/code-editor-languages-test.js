import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  clearRegisteredCodeEditorLanguages,
  loadCodeEditorLanguage,
  registerCodeEditorLanguage,
} from "discourse/lib/code-editor-languages";

const BUILT_IN = [
  "css",
  "html",
  "javascript",
  "json",
  "scss",
  "sql",
  "text",
  "yaml",
];

module("Unit | Utility | code-editor-languages", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    clearRegisteredCodeEditorLanguages();
  });

  test("resolves each built-in shortcut to extensions", async function (assert) {
    for (const name of BUILT_IN) {
      const build = await loadCodeEditorLanguage(name);

      assert.strictEqual(
        typeof build,
        "function",
        `${name} resolves to an extension builder`
      );
      assert.notStrictEqual(
        build({}),
        undefined,
        `${name} builds with no options`
      );
    }
  });

  test("is null for an unknown name", async function (assert) {
    assert.strictEqual(await loadCodeEditorLanguage("klingon"), null);
  });

  test("resolves a registered shortcut", async function (assert) {
    const extensions = [];
    registerCodeEditorLanguage("klingon", async () => ({
      default: () => extensions,
    }));

    const build = await loadCodeEditorLanguage("klingon");

    assert.strictEqual(build({}), extensions);
  });

  test("a registered shortcut overrides a built-in one", async function (assert) {
    const extensions = [];
    registerCodeEditorLanguage("sql", async () => ({
      default: () => extensions,
    }));

    assert.strictEqual((await loadCodeEditorLanguage("sql"))({}), extensions);
  });
});
