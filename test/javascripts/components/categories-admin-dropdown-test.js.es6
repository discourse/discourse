import componentTest from 'helpers/component-test';
moduleForComponent('categories-admin-dropdown', {integration: true});

componentTest('default', {
  template: '{{categories-admin-dropdown}}',

  test(assert) {
    const $selectBox = selectBox('.categories-admin-dropdown');

    assert.equal($selectBox.el.find(".d-icon-bars").length, 1);
    assert.equal($selectBox.el.find(".d-icon-caret-down").length, 1);

    expandSelectBox('.categories-admin-dropdown');

    andThen(() => {
      assert.equal($selectBox.rowByValue("create").name(), "New Category");
    });
  }
});
