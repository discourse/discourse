import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | activation-controls",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("hides change email button", {
      template: hbs`{{activation-controls}}`,
      beforeEach() {
        this.siteSettings.enable_local_logins = false;
        this.siteSettings.email_editable = false;
      },

      test(assert) {
        assert.ok(!exists("button.edit-email"));
      },
    });
  }
);
