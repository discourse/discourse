import componentTest from 'helpers/component-test';

moduleForComponent('select-box', { integration: true });

componentTest('updating the content refreshes the list', {
  template: '{{select-box value=1 content=content}}',

  beforeEach() {
    this.set("content", [{id:1, text:"robin"}]);
  },

  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-row .text").html().trim(), "robin");
    });
    andThen(() => this.set("content", [{id:1, text:"regis"}]));
    andThen(() => assert.equal(this.$(".select-box-row .text").html().trim(), "regis"));
  }
});

componentTest('accepts a value by reference', {
  template: '{{select-box value=value content=content}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{id:1, text:"robin"}, {id: 2, text:"regis"}]);
  },

  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-row.is-highlighted .text").html().trim(), "robin", "it highlights the row corresponding to the value");
    });

    andThen(() => {
      click(this.$(".select-box-row[title='robin']"));
      andThen(() => {
        assert.equal(this.get("value"), 1, "it mutates the value");
      });
    });
  }
});

componentTest('select-box can be filtered', {
  template: '{{select-box filterable=true value=1 content=content}}',

  beforeEach() {
    this.set("content", [{id:1, text:"robin"}, {id: 2, text:"regis"}]);
  },

  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => assert.equal(this.$(".filter-query").length, 1, "it has a search input"));

    andThen(() => {
      this.$(".filter-query").val("regis");
      this.$(".filter-query").trigger("keyup");
    });
    andThen(() => assert.equal(this.$(".select-box-row").length, 1, "it filters results"));

    andThen(() => {
      this.$(".filter-query").val("");
      this.$(".filter-query").trigger("keyup");
    });
    andThen(() => assert.equal(this.$(".select-box-row").length, 2, "it returns to original content when filter is empty"));
  }
});

componentTest('no default icon', {
  template: '{{select-box}}',

  test(assert) {
    assert.equal(this.$(".select-box-header .icon").length, 0, "it doesn’t have an icon if not specified");
  }
});

componentTest('customisable icon', {
  template: '{{select-box icon="shower"}}',

  test(assert) {
    assert.equal(this.$(".select-box-header .icon").html().trim(), "<i class=\"fa fa-shower d-icon d-icon-shower\"></i>", "it has a the correct icon");
  }
});

componentTest('default search icon', {
  template: '{{select-box filterable=true}}',

  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-filter .filter-icon").html().trim(), "<i class=\"fa fa-search d-icon d-icon-search\"></i>", "it has a the correct icon");
    });
  }
});

componentTest('with no search icon', {
  template: '{{select-box filterable=true searchIcon=null}}',

  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".search-icon").length, 0, "it has no icon");
    });
  }
});

componentTest('custom search icon', {
  template: '{{select-box filterable=true filterIcon="shower"}}',

  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-filter .filter-icon").html().trim(), "<i class=\"fa fa-shower d-icon d-icon-shower\"></i>", "it has a the correct icon");
    });
  }
});

componentTest('not filterable by default', {
  template: '{{select-box}}',
  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-filter").length, 0);
    });
  }
});


componentTest('select-box is expandable', {
  template: '{{select-box}}',
  test(assert) {
    click(".select-box-header");
    andThen(() => {
      assert.equal(this.$(".select-box").hasClass("is-expanded"), true);
    });

    click(".select-box-header");
    andThen(() => {
      assert.equal(this.$(".select-box").hasClass("is-expanded"), false);
    });
  }
});

componentTest('accepts custom id/text keys', {
  template: '{{select-box value=value content=content idKey="identifier" textKey="name"}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{identifier:1, name:"robin"}]);
  },

  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-row.is-highlighted .text").html().trim(), "robin");
    });
  }
});

componentTest('doesn’t render collection content before first expand', {
  template: '{{select-box value=1 content=content idKey="identifier" textKey="name"}}',

  beforeEach() {
    this.set("content", [{identifier:1, name:"robin"}]);
  },

  test(assert) {
    assert.equal(this.$(".select-box-body .collection").length, 0);

    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-body .collection").length, 1);
    });
  }
});

componentTest('persists filter state when expandind/collapsing', {
  template: '{{select-box value=1 content=content filterable=true}}',

  beforeEach() {
    this.set("content", [{id:1, text:"robin"}, {id:2, text:"régis"}]);
  },

  test(assert) {
    click(this.$(".select-box-header"));
    andThen(() => {
      this.$(".filter-query").val("rob");
      this.$(".filter-query").trigger("keyup");
    });

    andThen(() => {
      assert.equal(this.$(".select-box-row").length, 1);
    });

    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$().hasClass("is-expanded"), false);
    });

    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-row").length, 1);
    });
  }
});

componentTest('supports options to limit size', {
  template: '{{select-box maxWidth=100 maxCollectionHeight=20 content=content}}',

  beforeEach() {
    this.set("content", [{id:1, text:"robin"}]);
  },

  test(assert) {
    assert.equal(this.$(".select-box-header").outerWidth(), 100, "it limits the width");

    click(this.$(".select-box-header"));
    andThen(() => {
      assert.equal(this.$(".select-box-body").height(), 20, "it limits the height");
    });
  }
});
