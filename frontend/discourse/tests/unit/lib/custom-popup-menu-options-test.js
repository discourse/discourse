import { destroy } from "@ember/destroyable";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  addPopupMenuOption,
  clearPopupMenuOptions,
  customPopupMenuOptions,
} from "discourse/lib/composer/custom-popup-menu-options";

module("Unit | Lib | custom-popup-menu-options", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    clearPopupMenuOptions();
    this.firstOwner = {};
    this.secondOwner = {};
  });

  hooks.afterEach(function () {
    run(() => {
      destroy(this.firstOwner);
      destroy(this.secondOwner);
    });
    clearPopupMenuOptions();
  });

  test("owner cleanup preserves duplicate option identity, order and live changes", function (assert) {
    const sharedOption = { name: "shared" };
    const ownerlessOption = { name: "ownerless" };
    addPopupMenuOption(sharedOption, { owner: this.firstOwner });
    addPopupMenuOption(ownerlessOption);
    addPopupMenuOption(sharedOption, { owner: this.secondOwner });

    run(() => destroy(this.secondOwner));
    sharedOption.name = "updated";

    assert.deepEqual(
      customPopupMenuOptions.map((option) => option.name),
      ["updated", "ownerless"],
      "the earlier registration keeps its position and reflects changes to the original option"
    );
    assert.strictEqual(
      customPopupMenuOptions[0],
      sharedOption,
      "the original option object is preserved"
    );

    run(() => destroy(this.firstOwner));

    assert.deepEqual(
      customPopupMenuOptions,
      [ownerlessOption],
      "destroying both owners preserves the ownerless registration"
    );
  });

  test("old owner cleanup preserves the same option registered after reset", function (assert) {
    const sharedOption = { name: "shared" };
    addPopupMenuOption(sharedOption, { owner: this.firstOwner });
    clearPopupMenuOptions();
    addPopupMenuOption(sharedOption, { owner: this.secondOwner });

    run(() => destroy(this.firstOwner));

    assert.strictEqual(
      customPopupMenuOptions[0],
      sharedOption,
      "the replacement registration survives destruction of the previous owner"
    );

    run(() => destroy(this.secondOwner));

    assert.deepEqual(
      customPopupMenuOptions,
      [],
      "the replacement owner removes its own registration"
    );
  });
});
