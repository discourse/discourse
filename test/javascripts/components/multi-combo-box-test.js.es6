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
      assert.propEqual(selectBox(".multi-combobox").header.name(), 'hello,world');
    });
  }
});
