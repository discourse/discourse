import componentTest from 'helpers/component-test';
moduleForComponent('combo-box', {integration: true});

componentTest('default', {
  template: '{{combo-box content=items}}',
  beforeEach() {
    this.set('items', [{id: 1, name: 'hello'}, {id: 2, name: 'world'}]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').header.name(), "hello");
      assert.equal(selectKit('.combobox').rowByValue(1).name(), "hello");
      assert.equal(selectKit('.combobox').rowByValue(2).name(), "world");
    });
  }
});

componentTest('with valueAttribute', {
  template: '{{combo-box content=items valueAttribute="value"}}',
  beforeEach() {
    this.set('items', [{value: 0, name: 'hello'}, {value: 1, name: 'world'}]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').rowByValue(0).name(), "hello");
      assert.equal(selectKit('.combobox').rowByValue(1).name(), "world");
    });
  }
});

componentTest('with nameProperty', {
  template: '{{combo-box content=items nameProperty="text"}}',
  beforeEach() {
    this.set('items', [{id: 0, text: 'hello'}, {id: 1, text: 'world'}]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').rowByValue(0).name(), "hello");
      assert.equal(selectKit('.combobox').rowByValue(1).name(), "world");
    });
  }
});

componentTest('with an array as content', {
  template: '{{combo-box content=items value=value}}',
  beforeEach() {
    this.set('items', ['evil', 'trout', 'hat']);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').rowByValue('evil').name(), "evil");
      assert.equal(selectKit('.combobox').rowByValue('trout').name(), "trout");
    });
  }
});

componentTest('with value and none as a string', {
  template: '{{combo-box content=items none="test.none" value=value}}',
  beforeEach() {
    I18n.translations[I18n.locale].js.test = {none: 'none'};
    this.set('items', ['evil', 'trout', 'hat']);
    this.set('value', 'trout');
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').noneRow.name(), 'none');
      assert.equal(selectKit('.combobox').rowByValue("evil").name(), "evil");
      assert.equal(selectKit('.combobox').rowByValue("trout").name(), "trout");
      assert.equal(selectKit('.combobox').header.name(), 'trout');
      assert.equal(this.get('value'), 'trout');
    });

    selectKitSelectRow('__none__', {selector: '.combobox' });

    andThen(() => {
      assert.equal(this.get('value'), null);
    });
  }
});

componentTest('with value and none as an object', {
  template: '{{combo-box content=items none=none value=value}}',
  beforeEach() {
    this.set('none', { id: 'something', name: 'none' });
    this.set('items', ['evil', 'trout', 'hat']);
    this.set('value', 'evil');
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').noneRow.name(), 'none');
      assert.equal(selectKit('.combobox').rowByValue("evil").name(), "evil");
      assert.equal(selectKit('.combobox').rowByValue("trout").name(), "trout");
      assert.equal(selectKit('.combobox').header.name(), 'evil');
      assert.equal(this.get('value'), 'evil');
    });

    selectKitSelectNoneRow({ selector: '.combobox' });

    andThen(() => {
      assert.equal(this.get('value'), null);
    });
  }
});

componentTest('with no value and none as an object', {
  template: '{{combo-box content=items none=none value=value}}',
  beforeEach() {
    I18n.translations[I18n.locale].js.test = {none: 'none'};
    this.set('none', { id: 'something', name: 'none' });
    this.set('items', ['evil', 'trout', 'hat']);
    this.set('value', null);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').header.name(), 'none');
    });
  }
});

componentTest('with no value and none string', {
  template: '{{combo-box content=items none=none value=value}}',
  beforeEach() {
    I18n.translations[I18n.locale].js.test = {none: 'none'};
    this.set('none', 'test.none');
    this.set('items', ['evil', 'trout', 'hat']);
    this.set('value', null);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').header.name(), 'none');
    });
  }
});

componentTest('with no value and no none', {
  template: '{{combo-box content=items value=value}}',
  beforeEach() {
    this.set('items', ['evil', 'trout', 'hat']);
    this.set('value', null);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').header.name(), 'evil', 'it sets the first row as value');
    });
  }
});

// componentTest('can be filtered', {
//   template: '{{combo-box filterable=true value=1 content=content}}',
//
//   beforeEach() {
//     this.set("content", [{ id: 1, name: "robin"}, { id: 2, name: "regis" }]);
//   },
//
//   test(assert) {
//     ();
//
//     andThen(() => assert.equal(find(".filter-input").length, 1, "it has a search input"));
//
//     selectKitFillInFilter("regis");
//
//     andThen(() => assert.equal(selectKit().rows.length, 1, "it filters results"));
//
//     selectKitFillInFilter("");
//
//     andThen(() => {
//       assert.equal(
//         selectKit().rows.length, 2,
//         "it returns to original content when filter is empty"
//       );
//     });
//   }
// });

// componentTest('persists filter state when expanding/collapsing', {
//   template: '{{combo-box value=1 content=content filterable=true}}',
//
//   beforeEach() {
//     this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "régis" }]);
//   },
//
//   test(assert) {
//     ();
//
//     selectKitFillInFilter("rob");
//
//     andThen(() => assert.equal(selectKit().rows.length, 1) );
//
//     collapseSelectKit();
//
//     andThen(() => assert.notOk(selectKit().isExpanded) );
//
//     ();
//
//     andThen(() => assert.equal(selectKit().rows.length, 1) );
//   }
// });


componentTest('with empty string as value', {
  template: '{{combo-box content=items value=value}}',
  beforeEach() {
    this.set('items', ['evil', 'trout', 'hat']);
    this.set('value', '');
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit('.combobox').header.name(), 'evil', 'it sets the first row as value');
    });
  }
});
