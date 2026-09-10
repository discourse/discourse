import { destroy } from "@ember/destroyable";
import { run } from "@ember/runloop";
import { module, test } from "qunit";
import {
  clearRichEditorExtensions,
  getExtensions,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { getOwnerWithFallback, setDefaultOwner } from "discourse/lib/get-owner";
import initializer from "discourse/plugins/discourse-events/discourse/api-initializers/rich-editor-extension";

module("Unit | Initializer | rich-editor-extension", function (hooks) {
  hooks.beforeEach(async function () {
    this.previousOwner = getOwnerWithFallback();
    this.owners = [];
    await clearRichEditorExtensions();
  });

  hooks.afterEach(async function () {
    run(() => this.owners.forEach((owner) => destroy(owner)));
    setDefaultOwner(this.previousOwner);
    await resetRichEditorExtensions();
  });

  test("each owner uses its own event settings and removes its extension", function (assert) {
    const firstSettings = {
      discourse_post_event_enabled: true,
      discourse_post_event_allowed_custom_fields: "first_field",
    };
    const secondSettings = {
      discourse_post_event_enabled: false,
      discourse_post_event_allowed_custom_fields: "second_field",
    };
    const firstOwner = {};
    firstOwner.__container__ = {
      owner: firstOwner,
      lookup: () => firstSettings,
    };
    const secondOwner = {};
    secondOwner.__container__ = {
      owner: secondOwner,
      lookup: () => secondSettings,
    };
    this.owners.push(firstOwner, secondOwner);
    setDefaultOwner(firstOwner.__container__);
    initializer.initialize(firstOwner);

    const firstExtension = getExtensions()[0];
    assert.true(
      !!firstExtension.nodeViews.onebox,
      "the first owner enables event oneboxes"
    );
    assert.true(
      "firstField" in firstExtension.nodeSpec.event.attrs,
      "the first owner contributes its custom field"
    );

    run(() => destroy(firstOwner));
    assert.strictEqual(
      getExtensions().length,
      0,
      "the first owner's extension is removed"
    );
    setDefaultOwner(secondOwner.__container__);
    initializer.initialize(secondOwner);

    const secondExtension = getExtensions()[0];
    assert.strictEqual(
      getExtensions().length,
      1,
      "only the replacement extension is registered"
    );
    assert.false(
      !!secondExtension.nodeViews.onebox,
      "the second owner disables event oneboxes"
    );
    assert.false(
      "firstField" in secondExtension.nodeSpec.event.attrs,
      "the previous custom field is absent"
    );
    assert.true(
      "secondField" in secondExtension.nodeSpec.event.attrs,
      "the replacement custom field is present"
    );
  });
});
