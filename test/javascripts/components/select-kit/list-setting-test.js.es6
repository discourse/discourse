import componentTest from "helpers/component-test";
import { testSelectKitModule } from "./select-kit-test-helper";

testSelectKitModule("list-setting");

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
  }
});
