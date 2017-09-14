import componentTest from 'helpers/component-test';

moduleForComponent('select-box', { integration: true });

componentTest('updating the content refreshes the list', {
  template: '{{select-box value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.equal(selectBox().row(1).text(), "robin");
      this.set("content", [{ id: 1, text: "regis" }]);
      assert.equal(selectBox().row(1).text(), "regis");
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
    expandSelectBox();

    andThen(() => {
      assert.equal(
        selectBox().selectedRow.text(), "robin",
        "it highlights the row corresponding to the value"
      );
    });

    selectBoxSelectRow(1);

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
    expandSelectBox();

    andThen(() => assert.equal(find(".filter-query").length, 1, "it has a search input"));

    selectBoxFillInFilter("regis");

    andThen(() => assert.equal(selectBox().rows.length, 1, "it filters results"));

    selectBoxFillInFilter("");

    andThen(() => {
      assert.equal(
        selectBox().rows.length, 2,
        "it returns to original content when filter is empty"
      );
    });
  }
});

componentTest('no default icon', {
  template: '{{select-box}}',

  test(assert) {
    assert.equal(selectBox().header.icon().length, 0, "it doesn’t have an icon if not specified");
  }
});

componentTest('customisable icon', {
  template: '{{select-box icon="shower"}}',

  test(assert) {
    assert.ok(selectBox().header.icon().hasClass("d-icon-shower"), "it has a the correct icon");
  }
});

componentTest('default search icon', {
  template: '{{select-box filterable=true}}',

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.ok(selectBox().filter.icon().hasClass("d-icon-search"), "it has a the correct icon");
    });
  }
});

componentTest('with no search icon', {
  template: '{{select-box filterable=true filterIcon=null}}',

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.equal(selectBox().filter.icon().length, 0, "it has no icon");
    });
  }
});

componentTest('custom search icon', {
  template: '{{select-box filterable=true filterIcon="shower"}}',

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.ok(selectBox().filter.icon().hasClass("d-icon-shower"), "it has a the correct icon");
    });
  }
});

componentTest('not filterable by default', {
  template: '{{select-box}}',
  test(assert) {
    expandSelectBox();

    andThen(() => assert.notOk(selectBox().filter.exists()) );
  }
});

componentTest('select-box is expandable', {
  template: '{{select-box}}',
  test(assert) {
    expandSelectBox();

    andThen(() => assert.ok(selectBox().isExpanded) );

    collapseSelectBox();

    andThen(() => assert.notOk(selectBox().isExpanded) );
  }
});

componentTest('accepts custom id/text keys', {
  template: '{{select-box value=value content=content idKey="identifier" textKey="name"}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ identifier: 1, name: "robin" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.equal(selectBox().selectedRow.text(), "robin");
    });
  }
});

componentTest('doesn’t render collection content before first expand', {
  template: '{{select-box value=1 content=content idKey="identifier" textKey="name"}}',

  beforeEach() {
    this.set("content", [{ identifier: 1, name: "robin" }]);
  },

  test(assert) {
    assert.notOk(exists(find(".collection")));

    expandSelectBox();

    andThen(() => {
      assert.ok(exists(find(".collection")));
    });
  }
});

componentTest('persists filter state when expandind/collapsing', {
  template: '{{select-box value=1 content=content filterable=true}}',

  beforeEach() {
    this.set("content", [{id:1, text:"robin"}, {id:2, text:"régis"}]);
  },

  test(assert) {
    expandSelectBox();

    selectBoxFillInFilter("rob");

    andThen(() => assert.equal(selectBox().rows.length, 1) );

    collapseSelectBox();

    andThen(() => assert.notOk(selectBox().isExpanded) );

    expandSelectBox();

    andThen(() => assert.equal(selectBox().rows.length, 1) );
  }
});

componentTest('supports options to limit size', {
  template: '{{select-box collectionHeight=20 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => {
      const body = find(".select-box-body");
      assert.equal(parseInt(body.height()), 20, "it limits the height");
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
    expandSelectBox();

    andThen(() => assert.equal(selectBox().row(1).el().html(), "<b>robin</b>") );
  }
});

componentTest('supports converting select value to integer', {
  template: '{{select-box value=value content=content castInteger=true}}',

  beforeEach() {
    this.set("value", 2);
    this.set("content", [{ id: "1", text: "robin"}, {id: "2", text: "régis" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => assert.equal(selectBox().selectedRow.text(), "régis") );

    andThen(() => {
      this.set("value", 3);
      this.set("content", [{ id: "3", text: "jeff" }]);
    });

    andThen(() => {
      assert.equal(selectBox().selectedRow.text(), "jeff", "it works with dynamic content");
    });
  }
});

componentTest('dynamic headerText', {
  template: '{{select-box value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }, { id: 2, text: "regis" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => assert.equal(selectBox().header.text(), "robin") );

    selectBoxSelectRow(2);

    andThen(() => {
      assert.equal(selectBox().header.text(), "regis", "it changes header text");
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
    expandSelectBox();

    andThen(() => {
      assert.equal(selectBox().header.text(), "Choose...");
    });

    selectBoxSelectRow(2);

    andThen(() => {
      assert.equal(selectBox().header.text(), "Choose...", "it doesn’t change header text");
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
    expandSelectBox();

    andThen(() => assert.equal(selectBox().row(1).title(), "sam") );
  }
});

componentTest('supports keyboard events', {
  template: '{{select-box content=content filterable=true}}',

  beforeEach() {
    this.set("content", [{ id: 1, text: "robin" }, { id: 2, text: "regis" }]);
  },

  test(assert) {
    expandSelectBox();

    selectBox().keyboard.down();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.title(), "robin", "it highlights the first row");
    });

    selectBox().keyboard.down();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.title(), "regis", "it highlights the next row");
    });

    selectBox().keyboard.down();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.title(), "regis", "it keeps highlighting the last row when reaching the end");
    });

    selectBox().keyboard.up();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.title(), "robin", "it highlights the previous row");
    });

    selectBox().keyboard.enter();

    andThen(() => {
      assert.equal(selectBox().selectedRow.title(), "robin", "it selects the row when pressing enter");
      assert.notOk(selectBox().isExpanded, "it collapses the select box when selecting a row");
    });

    expandSelectBox();

    selectBox().keyboard.escape();

    andThen(() => {
      assert.notOk(selectBox().isExpanded, "it collapses the select box");
    });

    expandSelectBox();

    selectBoxFillInFilter("regis");

    andThen(() => {
      assert.equal(selectBox().highlightedRow.title(), "regis", "it highlights the first result");
    });

    selectBox().keyboard.tab();

    andThen(() => {
      assert.equal(selectBox().selectedRow.title(), "regis", "it selects the row when pressing tab");
      assert.notOk(selectBox().isExpanded, "it collapses the select box when selecting a row");
    });
  }
});
