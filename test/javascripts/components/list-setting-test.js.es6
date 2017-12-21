import componentTest from 'helpers/component-test';

moduleForComponent('list-setting', {integration: true});

componentTest('default', {
  template: '{{list-setting settingValue=settingValue choices=choices}}',

  beforeEach() {
    this.set('settingValue', 'bold|italic');
    this.set('choices', ['bold', 'italic', 'underline']);
  },

  test(assert) {
    andThen(() => {
      assert.propEqual(selectKit().header().title(), 'bold,italic');
      assert.propEqual(selectKit().header().value(), 'bold,italic');
    });
  }
});

componentTest('with title', {
  template: '{{list-setting title="test"}}',

  test(assert) {
    andThen(() => {
      assert.propEqual(selectKit().header().title(), 'test');
      assert.propEqual(selectKit().header().value(), null);
    });
  }
});

componentTest('with empty string as value', {
  template: '{{list-setting settingValue=settingValue}}',

  beforeEach() {
    this.set('settingValue', '');
  },

  test(assert) {
    andThen(() => {
      assert.propEqual(selectKit().header().value(), null);
    });
  }
});

componentTest('with only setting value', {
  template: '{{list-setting settingValue=settingValue}}',

  beforeEach() {
    this.set('settingValue', 'bold|italic');
  },

  test(assert) {
    andThen(() => {
      assert.propEqual(selectKit().header().value(), 'bold,italic');
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
    const listSetting = selectKit();

    listSetting.expand().selectRowByValue('underline');

    andThen(() => {
      assert.propEqual(listSetting.header().value(), 'bold,italic,underline');
    });

    listSetting.fillInFilter('strike');

    andThen(() => {
      assert.equal(listSetting.highlightedRow().value(), 'strike');
    });

    listSetting.keyboard().enter();

    andThen(() => {
      assert.propEqual(listSetting.header().value(), 'bold,italic,underline,strike');
    });

    listSetting.keyboard().backspace();
    listSetting.keyboard().backspace();

    andThen(() => {
      assert.equal(listSetting.header().value(), 'bold,italic,underline');
    });
  }
});
