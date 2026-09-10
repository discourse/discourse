import { destroy } from "@ember/destroyable";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  areDefaultExtensionsRegistered,
  clearRichEditorExtensions,
  getExtensions,
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";

module("Unit | Lib | rich-editor-extensions", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(async function () {
    this.firstOwner = {};
    this.secondOwner = {};
    await clearRichEditorExtensions();
  });

  hooks.afterEach(async function () {
    run(() => {
      destroy(this.firstOwner);
      destroy(this.secondOwner);
    });
    await resetRichEditorExtensions();
  });

  test("owner destruction preserves shared extension identity and order", function (assert) {
    const shared = { nodeSpec: {} };
    const middle = { markSpec: {} };
    registerRichEditorExtension(shared);
    registerRichEditorExtension(shared, { owner: this.firstOwner });
    registerRichEditorExtension(middle);
    registerRichEditorExtension(shared, { owner: this.secondOwner });
    const extensions = getExtensions();

    run(() => destroy(this.firstOwner));

    assert.strictEqual(
      getExtensions(),
      extensions,
      "the live array is retained"
    );
    assert.strictEqual(
      extensions.length,
      3,
      "only one registration is removed"
    );
    assert.strictEqual(
      extensions[0],
      shared,
      "the ownerless shared entry survives"
    );
    assert.strictEqual(
      extensions[1],
      middle,
      "the ownerless entry keeps its position"
    );
    assert.strictEqual(
      extensions[2],
      shared,
      "the other owner keeps the original object"
    );

    run(() => destroy(this.secondOwner));

    assert.deepEqual(
      getExtensions(),
      [shared, middle],
      "ownerless registrations survive both owners"
    );
  });

  test("an old owner cannot remove a registration made after clearing", async function (assert) {
    const extension = { nodeSpec: {} };
    registerRichEditorExtension(extension, { owner: this.firstOwner });
    await clearRichEditorExtensions();
    registerRichEditorExtension(extension, { owner: this.secondOwner });

    run(() => destroy(this.firstOwner));

    assert.strictEqual(
      getExtensions().length,
      1,
      "the new registration survives"
    );
    assert.strictEqual(
      getExtensions()[0],
      extension,
      "the extension is not cloned"
    );
  });

  test("reset defaults survive destruction of a previous owner", async function (assert) {
    await resetRichEditorExtensions();
    const defaults = [...getExtensions()];
    registerRichEditorExtension(defaults[0], { owner: this.firstOwner });

    await resetRichEditorExtensions();
    run(() => destroy(this.firstOwner));

    assert.deepEqual(
      getExtensions(),
      defaults,
      "defaults remain in their original order"
    );
    assert.true(areDefaultExtensionsRegistered(), "defaults remain registered");
  });
});
