import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
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
        assert.equal(queryAll("button.edit-email").length, 0);
      },
    });
  }
);
