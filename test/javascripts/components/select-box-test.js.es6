import componentTest from 'helpers/component-test';

moduleForComponent('select-box', { integration: true });

componentTest('updating the content refreshes the list', {
  template: '{{select-box value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }]);
  },

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-row .text").html().trim(), "robin");
      this.set("content", [{ id: 1, text: "regis" }]);
      assert.equal(find(".select-box-row .text").html().trim(), "regis");
    });
  }
});

componentTest('accepts a value by reference', {
  template: '{{select-box value=value content=content}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ id: 1, text: "robin" }, { id: 2, text: "regis" }]);
  },

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(
        find(".select-box-row.is-highlighted .text").html().trim(), "robin",
        "it highlights the row corresponding to the value"
      );
    });

    click(".select-box-row[title='robin']");

    andThen(() => {
      assert.equal(this.get("value"), 1, "it mutates the value");
    });
  }
});

componentTest('select-box can be filtered', {
  template: '{{select-box filterable=true value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin"}, { id: 2, text: "regis" }]);
  },

  test(assert) {
    click(".select-box-header");

    andThen(() => assert.equal(find(".filter-query").length, 1, "it has a search input"));

    fillIn(".filter-query", "regis");
    triggerEvent('.filter-query', 'keyup');

    andThen(() => assert.equal(find(".select-box-row").length, 1, "it filters results"));

    fillIn(".filter-query", "");
    triggerEvent('.filter-query', 'keyup');

    andThen(() => {
      assert.equal(
        find(".select-box-row").length, 2,
        "it returns to original content when filter is empty"
      );
    });
  }
});

componentTest('no default icon', {
  template: '{{select-box}}',

  test(assert) {
    assert.equal(find(".select-box-header .icon").length, 0, "it doesn’t have an icon if not specified");
  }
});

componentTest('customisable icon', {
  template: '{{select-box icon="shower"}}',

  test(assert) {
    assert.equal(find(".select-box-header .icon").hasClass("d-icon-shower"), true, "it has a the correct icon");
  }
});

componentTest('default search icon', {
  template: '{{select-box filterable=true}}',

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-filter .d-icon-search").length, 1, "it has a the correct icon");
    });
  }
});

componentTest('with no search icon', {
  template: '{{select-box filterable=true searchIcon=null}}',

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".search-icon").length, 0, "it has no icon");
    });
  }
});

componentTest('custom search icon', {
  template: '{{select-box filterable=true filterIcon="shower"}}',

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-filter .d-icon-shower").length, 1, "it has a the correct icon");
    });
  }
});

componentTest('not filterable by default', {
  template: '{{select-box}}',
  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-filter").length, 0);
    });
  }
});


componentTest('select-box is expandable', {
  template: '{{select-box}}',
  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box").hasClass("is-expanded"), true);
    });

    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box").hasClass("is-expanded"), false);
    });
  }
});

componentTest('accepts custom id/text keys', {
  template: '{{select-box value=value content=content idKey="identifier" textKey="name"}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ identifier: 1, name: "robin" }]);
  },

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-row.is-highlighted .text").html().trim(), "robin");
    });
  }
});

componentTest('doesn’t render collection content before first expand', {
  template: '{{select-box value=1 content=content idKey="identifier" textKey="name"}}',

  beforeEach() {
    this.set("content", [{ identifier: 1, name: "robin" }]);
  },

  test(assert) {
    assert.equal(find(".select-box-body .collection").length, 0);

    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-body .collection").length, 1);
    });
  }
});

componentTest('persists filter state when expandind/collapsing', {
  template: '{{select-box value=1 content=content filterable=true}}',

  beforeEach() {
    this.set("content", [{id:1, text:"robin"}, {id:2, text:"régis"}]);
  },

  test(assert) {
    click(".select-box-header");
    fillIn('.filter-query', 'rob');
    triggerEvent('.filter-query', 'keyup');

    andThen(() => {
      assert.equal(find(".select-box-row").length, 1);
    });

    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box").hasClass("is-expanded"), false);
    });

    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-row").length, 1);
    });
  }
});

componentTest('supports options to limit size', {
  template: '{{select-box collectionHeight=20 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }]);
  },

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(parseInt(find(".select-box-body").height()), 20, "it limits the height");
    });
  }
});

componentTest('supports custom row template', {
  template: '{{select-box content=content templateForRow=templateForRow}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }]);
    this.set("templateForRow", (rowComponent) => {
      return `<b>${rowComponent.get("content.text")}</b>`;
    });
  },

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-row").html().trim(), "<b>robin</b>");
    });
  }
});

componentTest('supports converting select value to integer', {
  template: '{{select-box value=value content=content castInteger=true}}',

  beforeEach() {
    this.set("value", 2);
    this.set("content", [{ id: "1", text: "robin"}, {id: "2", text: "régis" }]);
  },

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-row.is-highlighted .text").text(), "régis");
    });

    andThen(() => {
      this.set("value", 3);
      this.set("content", [{ id: "3", text: "jeff" }]);
    });

    andThen(() => {
      assert.equal(find(".select-box-row.is-highlighted .text").text(), "jeff", "it works with dynamic content");
    });
  }
});

componentTest('dynamic headerText', {
  template: '{{select-box value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }, { id: 2, text: "regis" }]);
  },

  test(assert) {
    click(".select-box-header");
    andThen(() => {
      assert.equal(find(".select-box-header .current-selection").html().trim(), "robin");
    });

    click(".select-box-row[title='regis']");
    andThen(() => {
      assert.equal(find(".select-box-header .current-selection").html().trim(), "regis", "it changes header text");
    });
  }
});

componentTest('static headerText', {
  template: '{{select-box value=1 content=content dynamicHeaderText=false headerText=headerText}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }, { id: 2, text: "regis" }]);
    this.set("headerText", "Choose...");
  },

  test(assert) {
    click(".select-box-header");
    andThen(() => {
      assert.equal(find(".select-box-header .current-selection").html().trim(), "Choose...");
    });

    click(".select-box-row[title='regis']");
    andThen(() => {
      assert.equal(find(".select-box-header .current-selection").html().trim(), "Choose...", "it doesn’t change header text");
    });
  }
});

componentTest('supports custom row title', {
  template: '{{select-box content=content titleForRow=titleForRow}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }]);
    this.set("titleForRow", () => "sam" );
  },

  test(assert) {
    click(".select-box-header");

    andThen(() => {
      assert.equal(find(".select-box-row:first").attr("title"), "sam");
    });
  }
});
