import componentTest from 'helpers/component-test';
moduleForComponent('categories-admin-dropdown', {integration: true});

componentTest('default', {
  template: '{{categories-admin-dropdown}}',

  test(assert) {
    const $selectKit = selectKit('.categories-admin-dropdown');

    assert.equal($selectKit.el.find(".d-bars").length, 1);
    assert.equal($selectKit.el.find(".d-caret-down").length, 1);

    expandSelectKit();

    andThen(() => {
      assert.equal($selectKit.rowByValue("create").name(), "New Category");
    });
  }
});
