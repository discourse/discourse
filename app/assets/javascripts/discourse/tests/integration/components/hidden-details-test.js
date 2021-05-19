import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";

discourseModule("Integration | Component | hidden-details", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("Shows a link and turns link into details on click", {
    template: hbs`{{hidden-details label=label details=details}}`,

    beforeEach() {
      this.set("label", "label");
      this.set("details", "details");
    },

    async test(assert) {
      assert.ok(exists(".btn-link"));
      assert.ok(query(".btn-link span").innerText === I18n.t("label"));
      assert.notOk(exists(".description"));

      await click(".btn-link");

      assert.notOk(exists(".btn-link"));
      assert.ok(exists(".description"));
      assert.ok(query(".description").innerText === "details");
    },
  });
});
