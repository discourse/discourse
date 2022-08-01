import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | emoji-picker", function (hooks) {
  setupRenderingTest(hooks);

  test("when placement == bottom, places the picker on the bottom", async function (assert) {
    this.set("showEmojiPicker", () => {
      this.set("pickerIsActive", true);
    });

    await render(hbs`
      <DButton class="emoji-picker-anchor" @action={{this.showEmojiPicker}} />
      <EmojiPicker @isActive={{this.pickerIsActive}} @placement="bottom" />
    `);

    await click(".emoji-picker-anchor");
    assert.strictEqual(
      query(".emoji-picker.opened").getAttribute("data-popper-placement"),
      "bottom"
    );
  });

  test("when placement == right, places the picker on the right", async function (assert) {
    this.set("showEmojiPicker", () => {
      this.set("pickerIsActive", true);
    });

    await render(hbs`
      <DButton class="emoji-picker-anchor" @action={{this.showEmojiPicker}} />
      <EmojiPicker @isActive={{this.pickerIsActive}} @placement="right" />
    `);

    await click(".emoji-picker-anchor");
    assert.strictEqual(
      query(".emoji-picker.opened").getAttribute("data-popper-placement"),
      "right"
    );
  });
});
