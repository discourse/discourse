import componentTest from 'helpers/component-test';
moduleForComponent('combo-box', {integration: true});

componentTest('with objects', {
  template: '{{combo-box content=items value=value}}',
  beforeEach() {
    this.set('items', [{id: 1, name: 'hello'}, {id: 2, name: 'world'}]);
  },

  test(assert) {
    expandSelectBox('.combobox');

    andThen(() => {
      assert.equal(selectBox('.combobox').row(1).text(), "hello");
      assert.equal(selectBox('.combobox').row(2).text(), "world");
    })
  }
});

componentTest('with valueAttribute', {
  template: '{{combo-box content=items valueAttribute="value"}}',
  beforeEach() {
    this.set('items', [{value: 0, name: 'hello'}, {value: 1, name: 'world'}]);
  },

  test(assert) {
    expandSelectBox('.combobox');

    andThen(() => {
      assert.equal(selectBox('.combobox').row(0).text(), "hello");
      assert.equal(selectBox('.combobox').row(1).text(), "world");
    })
  }
});

componentTest('with nameProperty', {
  template: '{{combo-box content=items nameProperty="text"}}',
  beforeEach() {
    this.set('items', [{id: 0, text: 'hello'}, {id: 1, text: 'world'}]);
  },

  test(assert) {
    expandSelectBox('.combobox');

    andThen(() => {
      assert.equal(selectBox('.combobox').row(0).text(), "hello");
      assert.equal(selectBox('.combobox').row(1).text(), "world");
    })
  }
});

componentTest('with an array as content', {
  template: '{{combo-box content=items value=value}}',
  beforeEach() {
    this.set('items', ['evil', 'trout', 'hat']);
  },

  test(assert) {
    expandSelectBox('.combobox');

    andThen(() => {
      assert.equal(selectBox('.combobox').row('evil').text(), "evil");
      assert.equal(selectBox('.combobox').row('trout').text(), "trout");
    })
  }
});

componentTest('with none as string', {
  template: '{{combo-box content=items none="test.none" value=value}}',
  beforeEach() {
    I18n.translations[I18n.locale].js.test = {none: 'none'};
    this.set('items', ['evil', 'trout', 'hat']);
  },

  test(assert) {
    expandSelectBox('.combobox');

    andThen(() => {
      assert.equal(selectBox('.combobox').noneRow.el().html().trim(), 'none');
      assert.equal(selectBox('.combobox').row("evil").text(), "evil");
      assert.equal(selectBox('.combobox').row("trout").text(), "trout");
    })
  }
});

componentTest('with none as an object', {
  template: '{{combo-box content=items none=none value=value selected="something"}}',
  beforeEach() {
    this.set('none', { id: 'something', name: 'none' });
    this.set('items', ['evil', 'trout', 'hat']);
  },

  test(assert) {
    expandSelectBox('.combobox');

    andThen(() => {
      assert.equal(selectBox('.combobox').noneRow.el().html().trim(), 'none');
      assert.equal(selectBox('.combobox').row("evil").text(), "evil");
      assert.equal(selectBox('.combobox').row("trout").text(), "trout");
    })


    // assert.equal(this.$("select option:eq(0)").val(), 'something');
  }
});
