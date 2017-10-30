import componentTest from 'helpers/component-test';

moduleForComponent('select-box-kit', { integration: true });

componentTest('updating the content refreshes the list', {
  template: '{{select-box-kit value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.equal(selectBox().rowByValue(1).name(), "robin");
      this.set("content", [{ id: 1, name: "regis" }]);
      assert.equal(selectBox().rowByValue(1).name(), "regis");
    });
  }
});

componentTest('accepts a value by reference', {
  template: '{{select-box-kit value=value content=content}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.equal(
        selectBox().selectedRow.name(), "robin",
        "it highlights the row corresponding to the value"
      );
    });

    selectBoxSelectRow(1);

    andThen(() => {
      assert.equal(this.get("value"), 1, "it mutates the value");
    });
  }
});

componentTest('no default icon', {
  template: '{{select-box-kit}}',

  test(assert) {
    assert.equal(selectBox().header.icon().length, 0, "it doesn’t have an icon if not specified");
  }
});

componentTest('default search icon', {
  template: '{{select-box-kit filterable=true}}',

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.ok(exists(selectBox().filter.icon), "it has a the correct icon");
    });
  }
});

componentTest('with no search icon', {
  template: '{{select-box-kit filterable=true filterIcon=null}}',

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.equal(selectBox().filter.icon().length, 0, "it has no icon");
    });
  }
});

componentTest('custom search icon', {
  template: '{{select-box-kit filterable=true filterIcon="shower"}}',

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.ok(selectBox().filter.icon().hasClass("d-icon-shower"), "it has a the correct icon");
    });
  }
});

componentTest('select-box is expandable', {
  template: '{{select-box-kit}}',
  test(assert) {
    expandSelectBox();

    andThen(() => assert.ok(selectBox().isExpanded) );

    collapseSelectBox();

    andThen(() => assert.notOk(selectBox().isExpanded) );
  }
});

componentTest('accepts custom value/name keys', {
  template: '{{select-box-kit value=value nameProperty="item" content=content valueAttribute="identifier"}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ identifier: 1, item: "robin" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => {
      assert.equal(selectBox().selectedRow.name(), "robin");
    });
  }
});

componentTest('doesn’t render collection content before first expand', {
  template: '{{select-box-kit value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ value: 1, name: "robin" }]);
  },

  test(assert) {
    assert.notOk(exists(find(".select-box-kit-collection")));

    expandSelectBox();

    andThen(() => {
      assert.ok(exists(find(".select-box-kit-collection")));
    });
  }
});

componentTest('supports options to limit size', {
  template: '{{select-box-kit collectionHeight=20 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => {
      const height = find(".select-box-kit-collection").height();
      assert.equal(parseInt(height, 10), 20, "it limits the height");
    });
  }
});

componentTest('dynamic headerText', {
  template: '{{select-box-kit value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => assert.equal(selectBox().header.name(), "robin") );

    selectBoxSelectRow(2);

    andThen(() => {
      assert.equal(selectBox().header.name(), "regis", "it changes header text");
    });
  }
});

componentTest('supports custom row template', {
  template: '{{select-box-kit content=content templateForRow=templateForRow}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }]);
    this.set("templateForRow", rowComponent => {
      return `<b>${rowComponent.get("content.name")}</b>`;
    });
  },

  test(assert) {
    expandSelectBox();

    andThen(() => assert.equal(selectBox().rowByValue(1).el.html().trim(), "<b>robin</b>") );
  }
});

componentTest('supports converting select value to integer', {
  template: '{{select-box-kit value=value content=content castInteger=true}}',

  beforeEach() {
    this.set("value", 2);
    this.set("content", [{ id: "1", name: "robin"}, {id: "2", name: "régis" }]);
  },

  test(assert) {
    expandSelectBox();

    andThen(() => assert.equal(selectBox().selectedRow.name(), "régis") );

    andThen(() => {
      this.set("value", 3);
      this.set("content", [{ id: "3", name: "jeff" }]);
    });

    andThen(() => {
      assert.equal(selectBox().selectedRow.name(), "jeff", "it works with dynamic content");
    });
  }
});

componentTest('supports keyboard events', {
  template: '{{select-box-kit content=content filterable=true}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  test(assert) {
    expandSelectBox();

    selectBox().keyboard.down();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.title(), "regis", "the next row is highlighted");
    });

    selectBox().keyboard.down();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.title(), "robin", "it returns to the first row");
    });

    selectBox().keyboard.up();

    andThen(() => {
      assert.equal(selectBox().highlightedRow.title(), "regis", "it highlights the last row");
    });

    selectBox().keyboard.enter();

    andThen(() => {
      assert.equal(selectBox().selectedRow.title(), "regis", "it selects the row when pressing enter");
      assert.notOk(selectBox().isExpanded, "it collapses the select box when selecting a row");
    });

    expandSelectBox();

    selectBox().keyboard.escape();

    andThen(() => {
      assert.notOk(selectBox().isExpanded, "it collapses the select box");
    });

    expandSelectBox();

    selectBoxFillInFilter("regis");

    // andThen(() => {
      // assert.equal(selectBox().highlightedRow.title(), "regis", "it highlights the first result");
    // });

    selectBox().keyboard.tab();

    andThen(() => {
      // assert.equal(selectBox().selectedRow.title(), "regis", "it selects the row when pressing tab");
      assert.notOk(selectBox().isExpanded, "it collapses the select box when selecting a row");
    });
  }
});


componentTest('supports mutating value when no value given', {
  template: '{{select-box-kit value=value content=content}}',

  beforeEach() {
    this.set("value", "");
    this.set("content", [{ id: "1", name: "robin"}, {id: "2", name: "régis" }]);
  },

  test(assert) {
    andThen(() => {
      assert.equal(this.get("value"), "1");
    });
  }
});
