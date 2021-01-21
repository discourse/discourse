import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

function template(options = []) {
  return `
    {{list-setting
      value=value
      choices=choices
      options=(hash
        ${options.join("\n")}
      )
    }}
  `;
}

discourseModule("Integration | Component | select-kit/list-setting", function (
  hooks
) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  componentTest("default", {
    template: template(),

    beforeEach() {
      this.set("value", ["bold", "italic"]);
      this.set("choices", ["bold", "italic", "underline"]);
    },

    async test(assert) {
      assert.equal(this.subject.header().name(), "bold,italic");
      assert.equal(this.subject.header().value(), "bold,italic");

      await this.subject.expand();

      assert.equal(this.subject.rows().length, 1);
      assert.equal(this.subject.rowByIndex(0).value(), "underline");
    },
  });
});
