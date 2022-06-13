import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { click } from "@ember/test-helpers";

discourseModule("Integration | Component | emoji-picker", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("when placement == bottom, places the picker on the bottom", {
    template: hbs`
      {{d-button class="emoji-picker-anchor" action=showEmojiPicker}}
      {{emoji-picker isActive=pickerIsActive placement="bottom"}}
    `,

    beforeEach() {
      this.set("showEmojiPicker", () => {
        this.set("pickerIsActive", true);
      });
    },

    async test(assert) {
      await click(".emoji-picker-anchor");
      assert.equal(
        query(".emoji-picker.opened").getAttribute("data-popper-placement"),
        "bottom"
      );
    },
  });

  componentTest("when placement == right, places the picker on the right", {
    template: hbs`
      {{d-button class="emoji-picker-anchor" action=showEmojiPicker}}
      {{emoji-picker isActive=pickerIsActive placement="right"}}
    `,

    beforeEach() {
      this.set("showEmojiPicker", () => {
        this.set("pickerIsActive", true);
      });
    },

    async test(assert) {
      await click(".emoji-picker-anchor");
      assert.equal(
        query(".emoji-picker.opened").getAttribute("data-popper-placement"),
        "right"
      );
    },
  });
});
