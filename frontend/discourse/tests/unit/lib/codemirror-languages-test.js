import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  clearRegisteredCodemirrorLanguages,
  codemirrorLanguageNames,
  loadCodemirrorLanguage,
  registerCodemirrorLanguage,
} from "discourse/lib/codemirror-languages";

module("Unit | Utility | codemirror-languages", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    clearRegisteredCodemirrorLanguages();
  });

  test("resolves each built-in shortcut to extensions", async function (assert) {
    for (const name of codemirrorLanguageNames()) {
      const build = await loadCodemirrorLanguage(name);

      assert.strictEqual(
        typeof build,
        "function",
        `${name} resolves to an extension builder`
      );
      assert.notStrictEqual(
        build(),
        undefined,
        `${name} builds without arguments it cannot supply`
      );
    }
  });

  test("is null for an unknown name", async function (assert) {
    assert.strictEqual(await loadCodemirrorLanguage("klingon"), null);
  });

  test("resolves a registered shortcut", async function (assert) {
    const extensions = [];
    registerCodemirrorLanguage("klingon", async () => ({
      default: () => extensions,
    }));

    const build = await loadCodemirrorLanguage("klingon");

    assert.strictEqual(build(), extensions);
    assert.true(codemirrorLanguageNames().includes("klingon"));
  });

  test("a registered shortcut overrides a built-in one", async function (assert) {
    const extensions = [];
    registerCodemirrorLanguage("sql", async () => ({
      default: () => extensions,
    }));

    assert.strictEqual((await loadCodemirrorLanguage("sql"))(), extensions);
  });
});
