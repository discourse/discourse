import componentTest from 'helpers/component-test';

moduleForComponent('list-setting', {integration: true});

componentTest('default', {
  template: '{{list-setting settingValue=settingValue choices=choices}}',

  beforeEach() {
    this.set('settingValue', 'bold|italic');
    this.set('choices', ['bold', 'italic', 'underline']);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.propEqual(selectKit().header.name(), 'bold,italic');
    });
  }
});

componentTest('with emptry string as value', {
  template: '{{list-setting settingValue=settingValue}}',

  beforeEach() {
    this.set('settingValue', '');
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().header.el.find(".selected-name").length, 0);
    });
  }
});

componentTest('with only setting value', {
  template: '{{list-setting settingValue=settingValue}}',

  beforeEach() {
    this.set('settingValue', 'bold|italic');
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.propEqual(selectKit().header.name(), 'bold,italic');
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
    expandSelectKit();

    selectKitSelectRow('underline');

    andThen(() => {
      assert.propEqual(selectKit().header.name(), 'bold,italic,underline');
    });

    selectKitFillInFilter('strike');

    andThen(() => {
      assert.equal(selectKit().highlightedRow.name(), 'strike');
    });

    selectKit().keyboard.enter();

    andThen(() => {
      assert.propEqual(selectKit().header.name(), 'bold,italic,underline,strike');
    });

    selectKit().keyboard.backspace();
    selectKit().keyboard.backspace();

    andThen(() => {
      assert.equal(this.get('choices').length, 3, 'it removes the created content from original list');
    });
  }
});
