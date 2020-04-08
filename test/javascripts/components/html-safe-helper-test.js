import componentTest from "helpers/component-test";
moduleForComponent("html-safe-helper", { integration: true });

componentTest("default", {
  template: "{{html-safe string}}",

  beforeEach() {
    this.set("string", "<p class='cookies'>biscuits</p>");
  },

  async test(assert) {
    assert.ok(exists("p.cookies"), "it displays the string as html");
  }
});
