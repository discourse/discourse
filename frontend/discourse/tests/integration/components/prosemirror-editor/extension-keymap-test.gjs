import { triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";

async function pressModE() {
  // "Mod-" resolves per platform at runtime, so send both variants
  await triggerKeyEvent(".ProseMirror", "keydown", "E", { metaKey: true });
  await triggerKeyEvent(".ProseMirror", "keydown", "E", { ctrlKey: true });
}

module(
  "Integration | Component | prosemirror-editor - extension keymap",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      await resetRichEditorExtensions();
    });

    hooks.afterEach(async function () {
      await resetRichEditorExtensions();
    });

    test("a later registration runs first and can fall through to an earlier one", async function (assert) {
      const calls = [];

      registerRichEditorExtension({
        keymap: () => ({
          "Mod-e": () => {
            calls.push("earlier");
            return true;
          },
        }),
      });
      registerRichEditorExtension({
        keymap: () => ({
          "Mod-e": () => {
            calls.push("later");
            return false;
          },
        }),
      });

      await setupRichEditor(assert, "");
      await pressModE();

      assert.deepEqual(
        calls,
        ["later", "earlier"],
        "the later registration ran first, then the chain fell through"
      );
    });

    test("a later registration overrides an earlier one by handling the key", async function (assert) {
      const calls = [];

      registerRichEditorExtension({
        keymap: () => ({
          "Mod-e": () => {
            calls.push("earlier");
            return true;
          },
        }),
      });
      registerRichEditorExtension({
        keymap: () => ({
          "Mod-e": () => {
            calls.push("later");
            return true;
          },
        }),
      });

      await setupRichEditor(assert, "");
      await pressModE();

      assert.deepEqual(calls, ["later"], "the earlier binding never ran");
    });
  }
);
