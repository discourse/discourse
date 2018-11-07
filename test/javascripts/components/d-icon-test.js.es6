import componentTest from "helpers/component-test";

moduleForComponent("d-icon", { integration: true });

componentTest("default", {
  template: '{{d-icon "bars"}}',

  test(assert) {
    const html = this.$()
      .html()
      .trim();
    assert.equal(
      html,
      '<svg class="fa d-icon d-icon-bars svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use xlink:href="#bars"></use></svg>'
    );
  }
});

componentTest("with replacement", {
  template: '{{d-icon "d-watching"}}',

  test(assert) {
    const html = this.$()
      .html()
      .trim();
    assert.equal(
      html,
      '<svg class="fa d-icon d-icon-d-watching svg-icon svg-string" xmlns="http://www.w3.org/2000/svg"><use xlink:href="#exclamation-circle"></use></svg>'
    );
  }
});
