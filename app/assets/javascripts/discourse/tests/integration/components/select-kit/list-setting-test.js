import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

discourseModule(
  "Integration | Component | select-kit/list-setting",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("default", {
      template: hbs`
      {{list-setting
        value=value
        choices=choices
      }}
    `,

      beforeEach() {
        this.set("value", ["bold", "italic"]);
        this.set("choices", ["bold", "italic", "underline"]);
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().name(), "bold,italic");
        assert.strictEqual(this.subject.header().value(), "bold,italic");

        await this.subject.expand();

        assert.strictEqual(this.subject.rows().length, 1);
        assert.strictEqual(this.subject.rowByIndex(0).value(), "underline");
      },
    });
  }
);
