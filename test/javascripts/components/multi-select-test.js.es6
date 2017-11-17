import componentTest from 'helpers/component-test';
moduleForComponent('multi-select', {integration: true});

componentTest('with objects and values', {
  template: '{{multi-select content=items values=values}}',

  beforeEach() {
    this.set('items', [{id: 1, name: 'hello'}, {id: 2, name: 'world'}]);
    this.set('values', [1, 2]);
  },

  test(assert) {
    andThen(() => {
      assert.propEqual(selectKit().header.name(), 'hello,world');
    });
  }
});

componentTest('interactions', {
  template: '{{multi-select none=none content=items values=values}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = {none: 'none'};
    this.set('items', [{id: 1, name: 'regis'}, {id: 2, name: 'sam'}, {id: 3, name: 'robin'}]);
    this.set('values', [1, 2]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().highlightedRow.name(), 'robin', 'it highlights the first content row');
    });

    this.set('none', 'test.none');

    andThen(() => {
      assert.equal(selectKit().noneRow.el.length, 1);
      assert.equal(selectKit().highlightedRow.name(), 'robin', 'it highlights the first content row');
    });

    selectKitSelectRow(3);

    andThen(() => {
      assert.equal(selectKit().highlightedRow.name(), 'none', 'it highlights none row if no content');
    });

    selectKitFillInFilter('joffrey');

    andThen(() => {
      assert.equal(selectKit().highlightedRow.name(), 'joffrey', 'it highlights create row when filling filter');
    });

    selectKit().keyboard.enter();

    andThen(() => {
      assert.equal(selectKit().highlightedRow.name(), 'none', 'it highlights none row after creating content and no content left');
    });

    selectKit().keyboard.backspace();

    andThen(() => {
      const $lastSelectedName = selectKit().header.el.find('.selected-name').last();
      assert.equal($lastSelectedName.attr('data-name'), 'joffrey');
      assert.ok($lastSelectedName.hasClass('is-highlighted'), 'it highlights the last selected name when using backspace');
    });

    selectKit().keyboard.backspace();

    andThen(() => {
      const $lastSelectedName = selectKit().header.el.find('.selected-name').last();
      assert.equal($lastSelectedName.attr('data-name'), 'robin', 'it removes the previous highlighted selected content');
      assert.notOk(exists(selectKit().rowByValue('joffrey').el), 'generated content shouldn’t appear in content when removed');
    });

    selectKit().keyboard.selectAll();

    andThen(() => {
      const $highlightedSelectedNames = selectKit().header.el.find('.selected-name.is-highlighted');
      assert.equal($highlightedSelectedNames.length, 3, 'it highlights each selected name');
    });

    selectKit().keyboard.backspace();

    andThen(() => {
      const $selectedNames = selectKit().header.el.find('.selected-name');
      assert.equal($selectedNames.length, 0, 'it removed all selected content');
    });

    andThen(() => {
      assert.ok(this.$(".select-kit").hasClass("is-focused"));
      assert.ok(this.$(".select-kit").hasClass("is-expanded"));
    });

    selectKit().keyboard.escape();

    andThen(() => {
      assert.ok(this.$(".select-kit").hasClass("is-focused"));
      assert.notOk(this.$(".select-kit").hasClass("is-expanded"));
    });

    selectKit().keyboard.escape();

    andThen(() => {
      assert.notOk(this.$(".select-kit").hasClass("is-focused"));
      assert.notOk(this.$(".select-kit").hasClass("is-expanded"));
    });
  }
});
