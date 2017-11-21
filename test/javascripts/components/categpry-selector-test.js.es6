import componentTest from 'helpers/component-test';
import Category from "discourse/models/category";

moduleForComponent('category-selector', {integration: true});

componentTest('default', {
  template: '{{category-selector categories=categories}}',

  beforeEach() {
    this.set('categories', [ Category.findById(2) ]);
  },

  test(assert) {
    andThen(() => {
      assert.propEqual(selectKit().header.name(), 'feature');
      assert.ok(!exists(".select-kit .select-kit-row[data-value='2']"), "selected categories are not in the list");
    });
  }
});

componentTest('with blacklist', {
  template: '{{category-selector categories=categories blacklist=blacklist}}',

  beforeEach() {
    this.set('categories', [ Category.findById(2) ]);
    this.set('blacklist', [ Category.findById(8) ]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.ok(exists(".select-kit .select-kit-row[data-value='6']"), "not blacklisted categories are in the list");
      assert.ok(!exists(".select-kit .select-kit-row[data-value='8']"), "blacklisted categories are not in the list");
    });
  }
});

componentTest('interactions', {
  template: '{{category-selector categories=categories}}',

  beforeEach() {
    this.set('categories', [
      Category.findById(2),
      Category.findById(6)
    ]);
  },

  test(assert) {
    expandSelectKit();

    selectKitSelectRow(8);

    andThen(() => {
      assert.propEqual(selectKit().header.name(), 'feature,support,hosting', 'it adds the selected category');
      assert.equal(this.get('categories').length, 3);
    });

    selectKit().keyboard.backspace();
    selectKit().keyboard.backspace();

    andThen(() => {
      assert.propEqual(selectKit().header.name(), 'feature,support', 'it removes the last selected category');
      assert.equal(this.get('categories').length, 2);
    });
  }
});
