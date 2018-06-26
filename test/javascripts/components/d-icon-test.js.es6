import componentTest from "helpers/component-test";

moduleForComponent("d-icon", { integration: true });

componentTest("default", {
  template: '{{d-icon "bars"}}',

  test(assert) {
    const html = this.$()
      .html()
      .trim();
    assert.equal(html, '<i class="fa fa-bars d-icon d-icon-bars"></i>');
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
      '<i class="fa fa-exclamation-circle d-icon d-icon-d-watching"></i>'
    );
  }
});
