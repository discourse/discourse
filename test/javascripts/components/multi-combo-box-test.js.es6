import componentTest from 'helpers/component-test';
moduleForComponent('multi-combo-box', {integration: true});

componentTest('with objects and values', {
  template: '{{multi-combo-box content=items value=value}}',

  beforeEach() {
    this.set('items', [{id: 1, name: 'hello'}, {id: 2, name: 'world'}]);
    this.set('value', [1, 2]);
  },

  test(assert) {
    andThen(() => {
      assert.propEqual(selectBox().header.name(), 'hello,world');
    });
  }
});

componentTest('interactions', {
  template: '{{multi-combo-box none=none content=items value=value}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = {none: 'none'};
    this.set('items', [{id: 1, name: 'regis'}, {id: 2, name: 'sam'}, {id: 3, name: 'robin'}]);
    this.set('value', [1, 2]);
  },

  test(assert) {
    expandSelectBoxKit();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.name(), 'robin', 'it highlights the first content row');
    });

    this.set('none', 'test.none');

    andThen(() => {
      assert.equal(selectBox().noneRow.el.length, 1);
      assert.equal(selectBox().highlightedRow.name(), 'robin', 'it highlights the first content row');
    });

    selectBoxKitSelectRow(3);

    andThen(() => {
      assert.equal(selectBox().highlightedRow.name(), 'none', 'it highlights none row if no content');
    });

    selectBoxKitFillInFilter('joffrey');

    andThen(() => {
      assert.equal(selectBox().highlightedRow.name(), 'joffrey', 'it highlights create row when filling filter');
    });

    selectBox().keyboard.enter();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.name(), 'none', 'it highlights none row after creating content and no content left');
    });

    selectBox().keyboard.backspace();

    andThen(() => {
      const $lastSelectedName = selectBox().header.el.find('.selected-name').last();
      assert.equal($lastSelectedName.attr('data-name'), 'joffrey');
      assert.ok($lastSelectedName.hasClass('is-highlighted'), 'it highlights the last selected name when using backspace');
    });

    selectBox().keyboard.backspace();

    andThen(() => {
      const $lastSelectedName = selectBox().header.el.find('.selected-name').last();
      assert.equal($lastSelectedName.attr('data-name'), 'robin', 'it removes the previous highlighted selected content');
      assert.notOk(exists(selectBox().rowByValue('joffrey').el), 'generated content shouldn’t appear in content when removed');
    });

    selectBox().keyboard.selectAll();

    andThen(() => {
      const $highlightedSelectedNames = selectBox().header.el.find('.selected-name.is-highlighted');
      assert.equal($highlightedSelectedNames.length, 3, 'it highlights each selected name');
    });

    selectBox().keyboard.backspace();

    andThen(() => {
      const $selectedNames = selectBox().header.el.find('.selected-name');
      assert.equal($selectedNames.length, 0, 'it removed all selected content');
    });

    andThen(() => {
      assert.ok(this.$(".select-box-kit").hasClass("is-focused"));
      assert.ok(this.$(".select-box-kit").hasClass("is-expanded"));
    });

    selectBox().keyboard.escape();

    andThen(() => {
      assert.ok(this.$(".select-box-kit").hasClass("is-focused"));
      assert.notOk(this.$(".select-box-kit").hasClass("is-expanded"));
    });

    selectBox().keyboard.escape();

    andThen(() => {
      assert.notOk(this.$(".select-box-kit").hasClass("is-focused"));
      assert.notOk(this.$(".select-box-kit").hasClass("is-expanded"));
    });
  }
});
