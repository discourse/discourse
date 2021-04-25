import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule(
  "Integration | Component | details-under-link",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("Shows a link and turns link into details on click", {
      template: hbs`{{details-under-link label=label details=details}}`,

      beforeEach() {
        this.set("link", "link");
        this.set("details", "details");
      },

      async test(assert) {
        assert.ok(exists(".btn-link"));
        assert.notOk(exists(".details"));

        await click(".btn-link");

        assert.notOk(exists(".btn-link"));
        assert.ok(exists(".details"));
      },
    });
  }
);
