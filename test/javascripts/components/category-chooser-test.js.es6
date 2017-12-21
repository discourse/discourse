import componentTest from 'helpers/component-test';

moduleForComponent('category-chooser', {
  integration: true,
  beforeEach: function() {
    this.set('subject', selectKit());
  }
});

componentTest('with value', {
  template: '{{category-chooser value=2}}',

  test(assert) {
    andThen(() => {
      assert.equal(this.get('subject').header().value(), 2);
      assert.equal(this.get('subject').header().title(), 'feature');
    });
  }
});

componentTest('with excludeCategoryId', {
  template: '{{category-chooser excludeCategoryId=2}}',

  test(assert) {
    this.get('subject').expand();

    andThen(() => assert.notOk(this.get('subject').rowByValue(2).exists()));
  }
});

componentTest('with scopedCategoryId', {
  template: '{{category-chooser scopedCategoryId=2}}',

  test(assert) {
    this.get('subject').expand();

    andThen(() => {
      assert.equal(this.get('subject').rowByIndex(0).title(), 'feature');
      assert.equal(this.get('subject').rowByIndex(0).value(), 2);
      assert.equal(this.get('subject').rowByIndex(1).title(), 'spec');
      assert.equal(this.get('subject').rowByIndex(1).value(), 26);
      assert.equal(this.get('subject').rows().length, 2);
    });
  }
});

componentTest('with allowUncategorized=null', {
  template: '{{category-chooser allowUncategorized=null}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    andThen(() => {
      assert.equal(this.get('subject').header().value(), null);
      assert.equal(this.get('subject').header().title(), "Select a category&hellip;");
    });
  }
});

componentTest('with allowUncategorized=null rootNone=true', {
  template: '{{category-chooser allowUncategorized=null rootNone=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    andThen(() => {
      assert.equal(this.get('subject').header().value(), null);
      assert.equal(this.get('subject').header().title(), 'Select a category&hellip;');
    });
  }
});

componentTest('with disallowed uncategorized, rootNone and rootNoneLabel', {
  template: '{{category-chooser allowUncategorized=null rootNone=true rootNoneLabel="test.root"}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { root: 'root none label' };
    this.siteSettings.allow_uncategorized_topics = false;
  },

  test(assert) {
    andThen(() => {
      assert.equal(this.get('subject').header().value(), null);
      assert.equal(this.get('subject').header().title(), 'Select a category&hellip;');
    });
  }
});

componentTest('with allowed uncategorized', {
  template: '{{category-chooser allowUncategorized=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    andThen(() => {
      assert.equal(this.get('subject').header().value(), null);
      assert.equal(this.get('subject').header().title(), 'uncategorized');
    });
  }
});

componentTest('with allowed uncategorized and rootNone', {
  template: '{{category-chooser allowUncategorized=true rootNone=true}}',

  beforeEach() {
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    andThen(() => {
      assert.equal(this.get('subject').header().value(), null);
      assert.equal(this.get('subject').header().title(), '(no category)');
    });
  }
});

componentTest('with allowed uncategorized rootNone and rootNoneLabel', {
  template: '{{category-chooser allowUncategorized=true rootNone=true rootNoneLabel="test.root"}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { root: 'root none label' };
    this.siteSettings.allow_uncategorized_topics = true;
  },

  test(assert) {
    andThen(() => {
      assert.equal(this.get('subject').header().value(), null);
      assert.equal(this.get('subject').header().title(), 'root none label');
    });
  }
});
