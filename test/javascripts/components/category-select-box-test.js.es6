import componentTest from 'helpers/component-test';
// import Category from 'discourse/models/category';
//
// const buildCategory = function(name, parent_category_id, color, text_color) {
//   return Category.create({
//     name,
//     color,
//     text_color,
//     parent_category_id,
//     read_restricted: false
//   });
// };

moduleForComponent('category-select-box', {integration: true});

componentTest('with value', {
  template: '{{category-select-box value=2}}',

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      assert.equal(selectBox('.category-select-box').header.text(), "feature");
    });
  }
});

componentTest('with excludeCategoryId', {
  template: '{{category-select-box excludeCategoryId=2}}',

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      assert.equal(selectBox('.category-select-box').row("2").el.length, 0);
    });
  }
});

componentTest('with allowUncategorized=null', {
  template: '{{category-select-box allowUncategorized=null}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      assert.equal(selectBox('.category-select-box').header.text(), "Select a category…");
    });
  }
});

componentTest('with allowUncategorized=null rootNone=true', {
  template: '{{category-select-box allowUncategorized=null rootNone=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      assert.equal(selectBox('.category-select-box').header.text(), "Select a category…");
    });
  }
});

componentTest('with disallowed uncategorized, rootNone and rootNoneLabel', {
  template: '{{category-select-box allowUncategorized=null rootNone=true rootNoneLabel="test.root"}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = {root: 'root none label'};
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      assert.equal(selectBox('.category-select-box').header.text(), "Select a category…");
    });
  }
});

componentTest('with allowed uncategorized', {
  template: '{{category-select-box allowUncategorized=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      assert.equal(selectBox('.category-select-box').header.text(), "uncategorized");
    });
  }
});

componentTest('with allowed uncategorized and rootNone', {
  template: '{{category-select-box allowUncategorized=true rootNone=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      assert.equal(selectBox('.category-select-box').header.text(), "(no category)");
    });
  }
});

componentTest('with allowed uncategorized rootNone and rootNoneLabel', {
  template: '{{category-select-box allowUncategorized=true rootNone=true rootNoneLabel="test.root"}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = {root: 'root none label'};
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    expandSelectBox('.category-select-box');

    andThen(() => {
      assert.equal(selectBox('.category-select-box').header.text(), "root none label");
    });
  }
});
