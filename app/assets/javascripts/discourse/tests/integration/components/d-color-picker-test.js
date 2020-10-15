import { moduleForComponent } from "ember-qunit";
import componentTest from "discourse/tests/helpers/component-test";

moduleForComponent("d-color-picker", { integration: true });

async function fillPickerInput(value) {
  return await fillIn(".d-color-picker .color-value", value);
}

componentTest("color is undefined", {
  template: "{{d-color-picker color=color onChange=(fn (mut color))}}",

  beforeEach() {
    this.set("color", "");
  },

  async test(assert) {
    assert.equal(this.color, "");
  },
});

componentTest("user fills color input", {
  template: "{{d-color-picker color=color onChange=(fn (mut color))}}",

  beforeEach() {
    this.set("color", "");
  },

  async test(assert) {
    await fillPickerInput("#456745");
    assert.equal(this.color, "456745");
  },
});

componentTest("user fills invalid color input", {
  template: "{{d-color-picker color=color onChange=(fn (mut color))}}",

  beforeEach() {
    this.set("color", "");
  },

  async test(assert) {
    await fillPickerInput("@-_-!");
    assert.equal(this.color, "");
  },
});
