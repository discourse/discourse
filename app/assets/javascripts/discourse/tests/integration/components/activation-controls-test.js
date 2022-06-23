import { hbs } from "ember-cli-htmlbars";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";

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
