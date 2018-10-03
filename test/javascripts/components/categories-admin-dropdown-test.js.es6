import componentTest from "helpers/component-test";
moduleForComponent("categories-admin-dropdown", { integration: true });

componentTest("default", {
  template: "{{categories-admin-dropdown}}",

  async test(assert) {
    const subject = selectKit();

    assert.equal(subject.el().find(".d-icon-bars").length, 1);

    await subject.expand();

    assert.equal(subject.rowByValue("create").name(), "New Category");
  }
});
