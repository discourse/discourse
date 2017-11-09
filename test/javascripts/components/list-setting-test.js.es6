import componentTest from 'helpers/component-test';

moduleForComponent('list-setting', {integration: true});

componentTest('default', {
  template: '{{list-setting settingValue=settingValue choices=choices}}',

  beforeEach() {
    this.set('settingValue', 'bold|italic');
    this.set('choices', ['bold', 'italic', 'underline']);
  },

  test(assert) {
    expandSelectBoxKit();

    andThen(() => {
      assert.propEqual(selectBox().header.name(), 'bold,italic');
    });
  }
});

componentTest('with only setting value', {
  template: '{{list-setting settingValue=settingValue}}',

  beforeEach() {
    this.set('settingValue', 'bold|italic');
  },

  test(assert) {
    expandSelectBoxKit();

    andThen(() => {
      assert.propEqual(selectBox().header.name(), 'bold,italic');
    });
  }
});

componentTest('interactions', {
  template: '{{list-setting settingValue=settingValue choices=choices}}',

  beforeEach() {
    this.set('settingValue', 'bold|italic');
    this.set('choices', ['bold', 'italic', 'underline']);
  },

  test(assert) {
    expandSelectBoxKit();

    selectBoxKitSelectRow('underline');

    andThen(() => {
      assert.propEqual(selectBox().header.name(), 'bold,italic,underline');
    });

    selectBoxKitFillInFilter('strike');

    andThen(() => {
      assert.equal(selectBox().highlightedRow.name(), 'strike');
    });

    selectBox().keyboard.enter();

    andThen(() => {
      assert.propEqual(selectBox().header.name(), 'bold,italic,underline,strike');
    });

    selectBox().keyboard.backspace();
    selectBox().keyboard.backspace();

    andThen(() => {
      assert.equal(this.get('choices').length, 3, 'it removes the created content from original list');
    });
  }
});
