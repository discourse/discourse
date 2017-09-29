import componentTest from 'helpers/component-test';
moduleForComponent('categories-admin-dropdown', {integration: true});

componentTest('default', {
  template: '{{categories-admin-dropdown}}',

  test(assert) {
    const $selectBox = selectBox('.categories-admin-dropdown');

    assert.equal($selectBox.el.find(".d-icon").length, 2);

    expandSelectBox('.categories-admin-dropdown');

    andThen(() => {
      assert.equal($selectBox.row("create").el.find(".title").text(), "New Category");
    });
  }
});
