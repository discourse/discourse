import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";

discourseModule("Integration | Component | activation-controls", function (
  hooks
) {
  setupRenderingTest(hooks);

  componentTest("hides change email button", {
    template: `{{activation-controls}}`,
    beforeEach() {
      this.siteSettings.enable_local_logins = false;
      this.siteSettings.email_editable = false;
    },

    test(assert) {
      assert.equal(queryAll("button.edit-email").length, 0);
    },
  });
});
