import componentTest from 'helpers/component-test';

moduleForComponent('category-chooser', {integration: true});

componentTest('with value', {
  template: '{{category-chooser value=2}}',

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').header.name(), "feature");
    });
  }
});

componentTest('with excludeCategoryId', {
  template: '{{category-chooser excludeCategoryId=2}}',

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').rowByValue(2).el.length, 0);
    });
  }
});

componentTest('with scopedCategoryId', {
  template: '{{category-chooser scopedCategoryId=2}}',

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').rowByIndex(0).name(), "feature");
      assert.equal(selectBox('.category-chooser').rowByIndex(1).name(), "spec");
      assert.equal(selectBox('.category-chooser').el.find(".select-box-kit-row").length, 2);
    });
  }
});

componentTest('with allowUncategorized=null', {
  template: '{{category-chooser allowUncategorized=null}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').header.name(), "Select a category&hellip;");
    });
  }
});

componentTest('with allowUncategorized=null rootNone=true', {
  template: '{{category-chooser allowUncategorized=null rootNone=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').header.name(), "Select a category&hellip;");
    });
  }
});

componentTest('with disallowed uncategorized, rootNone and rootNoneLabel', {
  template: '{{category-chooser allowUncategorized=null rootNone=true rootNoneLabel="test.root"}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = {root: 'root none label'};
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').header.name(), "Select a category&hellip;");
    });
  }
});

componentTest('with allowed uncategorized', {
  template: '{{category-chooser allowUncategorized=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').header.name(), "uncategorized");
    });
  }
});

componentTest('with allowed uncategorized and rootNone', {
  template: '{{category-chooser allowUncategorized=true rootNone=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').header.name(), "(no category)");
    });
  }
});

componentTest('with allowed uncategorized rootNone and rootNoneLabel', {
  template: '{{category-chooser allowUncategorized=true rootNone=true rootNoneLabel="test.root"}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = {root: 'root none label'};
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    expandSelectBox('.category-chooser');

    andThen(() => {
      assert.equal(selectBox('.category-chooser').header.name(), "root none label");
    });
  }
});
