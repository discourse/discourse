import componentTest from 'helpers/component-test';
moduleForComponent('combo-box', {integration: true});

componentTest('with objects', {
  template: '{{combo-box content=items value=value}}',
  setup() {
    this.set('items', [{id: 1, name: 'hello'}, {id: 2, name: 'world'}]);
  },

  test(assert) {
    assert.equal(this.get('value'), 1);
    assert.ok(this.$('.combobox').length);
    assert.equal(this.$("select option[value='1']").text(), 'hello');
    assert.equal(this.$("select option[value='2']").text(), 'world');
  }
});

componentTest('with objects and valueAttribute', {
  template: '{{combo-box content=items valueAttribute="value"}}',
  setup() {
    this.set('items', [{value: 0, name: 'hello'}, {value: 1, name: 'world'}]);
  },

  test(assert) {
    assert.ok(this.$('.combobox').length);
    assert.equal(this.$("select option[value='0']").text(), 'hello');
    assert.equal(this.$("select option[value='1']").text(), 'world');
  }
});

componentTest('with an array', {
  template: '{{combo-box content=items value=value}}',
  setup() {
    this.set('items', ['evil', 'trout', 'hat']);
  },

  test(assert) {
    assert.equal(this.get('value'), 'evil');
    assert.ok(this.$('.combobox').length);
    assert.equal(this.$("select option[value='evil']").text(), 'evil');
    assert.equal(this.$("select option[value='trout']").text(), 'trout');
  }
});

componentTest('with none', {
  template: '{{combo-box content=items none="test.none" value=value}}',
  setup() {
    I18n.translations[I18n.locale].js.test = {none: 'none'};
    this.set('items', ['evil', 'trout', 'hat']);
  },

  test(assert) {
    assert.equal(this.$("select option:eq(0)").text(), 'none');
    assert.equal(this.$("select option:eq(0)").val(), '');
    assert.equal(this.$("select option:eq(1)").text(), 'evil');
    assert.equal(this.$("select option:eq(2)").text(), 'trout');
  }
});
