import componentTest from "helpers/component-test";
moduleForComponent("categories-admin-dropdown", { integration: true });

componentTest("default", {
  template: "{{categories-admin-dropdown}}",

  test(assert) {
    const subject = selectKit();

    assert.equal(subject.el().find(".d-icon-bars").length, 1);
    assert.equal(subject.el().find(".d-icon-caret-down").length, 1);

    subject.expand();

    andThen(() => {
      assert.equal(subject.rowByValue("create").name(), "New Category");
    });
  }
});
