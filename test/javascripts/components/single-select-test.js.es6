import componentTest from 'helpers/component-test';
import { withPluginApi } from 'discourse/lib/plugin-api';
import { clearCallbacks } from 'select-kit/mixins/plugin-api';

moduleForComponent('single-select', { integration: true });

componentTest('updating the content refreshes the list', {
  template: '{{single-select value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "BEFORE" }]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().rowByValue(1).name(), "BEFORE");
    });

    andThen(() => {
      this.set("content", [{ id: 1, name: "AFTER" }]);
    });

    andThen(() => {
      assert.equal(selectKit().rowByValue(1).name(), "AFTER");
    });
  }
});

componentTest('accepts a value by reference', {
  template: '{{single-select value=value content=content}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(
        selectKit().selectedRow.name(), "robin",
        "it highlights the row corresponding to the value"
      );
    });

    selectKitSelectRow(1);

    andThen(() => {
      assert.equal(this.get("value"), 1, "it mutates the value");
    });
  }
});

componentTest('no default icon', {
  template: '{{single-select}}',

  test(assert) {
    assert.equal(selectKit().header.icon().length, 0, "it doesn’t have an icon if not specified");
  }
});

componentTest('default search icon', {
  template: '{{single-select filterable=true}}',

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.ok(exists(selectKit().filter.icon), "it has a the correct icon");
    });
  }
});

componentTest('with no search icon', {
  template: '{{single-select filterable=true filterIcon=null}}',

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().filter.icon().length, 0, "it has no icon");
    });
  }
});

componentTest('custom search icon', {
  template: '{{single-select filterable=true filterIcon="shower"}}',

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.ok(selectKit().filter.icon().hasClass("fa-shower"), "it has a the correct icon");
    });
  }
});

componentTest('is expandable', {
  template: '{{single-select}}',
  test(assert) {
    expandSelectKit();

    andThen(() => assert.ok(selectKit().isExpanded) );

    collapseSelectKit();

    andThen(() => assert.notOk(selectKit().isExpanded) );
  }
});

componentTest('accepts custom value/name keys', {
  template: '{{single-select value=value nameProperty="item" content=content valueAttribute="identifier"}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ identifier: 1, item: "robin" }]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().selectedRow.name(), "robin");
    });
  }
});

componentTest('doesn’t render collection content before first expand', {
  template: '{{single-select value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ value: 1, name: "robin" }]);
  },

  test(assert) {
    assert.notOk(exists(find(".select-kit-collection")));

    expandSelectKit();

    andThen(() => {
      assert.ok(exists(find(".select-kit-collection")));
    });
  }
});

componentTest('supports options to limit size', {
  template: '{{single-select collectionHeight=20 content=content}}',

  beforeEach() {
    this.set("content", ["robin", "régis"]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      const height = find(".select-kit-collection").height();
      assert.equal(parseInt(height, 10), 20, "it limits the height");
    });
  }
});

componentTest('dynamic headerText', {
  template: '{{single-select value=1 content=content}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().header.name(), "robin");
    });

    selectKitSelectRow(2);

    andThen(() => {
      assert.equal(selectKit().header.name(), "regis", "it changes header text");
    });
  }
});

componentTest('supports custom row template', {
  template: '{{single-select content=content templateForRow=templateForRow}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }]);
    this.set("templateForRow", rowComponent => {
      return `<b>${rowComponent.get("computedContent.name")}</b>`;
    });
  },

  test(assert) {
    expandSelectKit();

    andThen(() => assert.equal(selectKit().rowByValue(1).el.html().trim(), "<b>robin</b>") );
  }
});

componentTest('supports converting select value to integer', {
  template: '{{single-select value=value content=content castInteger=true}}',

  beforeEach() {
    this.set("value", 2);
    this.set("content", [{ id: "1", name: "robin"}, {id: "2", name: "régis" }]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => assert.equal(selectKit().selectedRow.name(), "régis") );

    andThen(() => {
      this.set("value", 3);
      this.set("content", [{ id: "3", name: "jeff" }]);
    });

    andThen(() => {
      assert.equal(selectKit().selectedRow.name(), "jeff", "it works with dynamic content");
    });
  }
});

componentTest('supports keyboard events', {
  template: '{{single-select content=content filterable=true}}',

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  test(assert) {
    expandSelectKit();

    selectKit().keyboard.down();

    andThen(() => {
      assert.equal(selectKit().highlightedRow.title(), "regis", "the next row is highlighted");
    });

    selectKit().keyboard.down();

    andThen(() => {
      assert.equal(selectKit().highlightedRow.title(), "robin", "it returns to the first row");
    });

    selectKit().keyboard.up();

    andThen(() => {
      assert.equal(selectKit().highlightedRow.title(), "regis", "it highlights the last row");
    });

    selectKit().keyboard.enter();

    andThen(() => {
      assert.equal(selectKit().selectedRow.title(), "regis", "it selects the row when pressing enter");
      assert.notOk(selectKit().isExpanded, "it collapses the select box when selecting a row");
    });

    expandSelectKit();

    selectKit().keyboard.escape();

    andThen(() => {
      assert.notOk(selectKit().isExpanded, "it collapses the select box");
    });

    expandSelectKit();

    selectKitFillInFilter("regis");

    selectKit().keyboard.tab();

    andThen(() => {
      assert.notOk(selectKit().isExpanded, "it collapses the select box when selecting a row");
    });
  }
});


componentTest('with allowInitialValueMutation', {
  template: '{{single-select value=value content=content allowInitialValueMutation=true}}',

  beforeEach() {
    this.set("value", "");
    this.set("content", [{ id: "1", name: "robin"}, {id: "2", name: "régis" }]);
  },

  test(assert) {
    andThen(() => {
      assert.equal(this.get("value"), "1", "it mutates the value on initial rendering");
    });
  }
});

componentTest('support appending content through plugin api', {
  template: '{{single-select content=content}}',

  beforeEach() {
    withPluginApi('0.8.13', api => {
      api.modifySelectKit("select-kit")
         .appendContent([{ id: "2", name: "regis"}]);
    });

    this.set("content", [{ id: "1", name: "robin"}]);
  },
  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().rows.length, 2);
      assert.equal(selectKit().rows.eq(1).data("name"), "regis");
    });

    andThen(() => clearCallbacks());
  }
});

componentTest('support modifying content through plugin api', {
  template: '{{single-select content=content}}',

  beforeEach() {
    withPluginApi('0.8.13', api => {
      api.modifySelectKit("select-kit")
         .modifyContent((context, existingContent) => {
           existingContent.splice(1, 0, { id: "2", name: "sam" });
           return existingContent;
         });
    });

    this.set("content", [{ id: "1", name: "robin"}, { id: "3", name: "regis"}]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().rows.length, 3);
      assert.equal(selectKit().rows.eq(1).data("name"), "sam");
    });

    andThen(() => clearCallbacks());
  }
});

componentTest('support prepending content through plugin api', {
  template: '{{single-select content=content}}',

  beforeEach() {
    withPluginApi('0.8.13', api => {
      api.modifySelectKit("select-kit")
         .prependContent([{ id: "2", name: "regis"}]);
    });

    this.set("content", [{ id: "1", name: "robin"}]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().rows.length, 2);
      assert.equal(selectKit().rows.eq(0).data("name"), "regis");
    });

    andThen(() => clearCallbacks());
  }
});

componentTest('support modifying on select behavior through plugin api', {
  template: '<span class="on-select-test"></span>{{single-select content=content}}',

  beforeEach() {
    withPluginApi('0.8.13', api => {
      api
        .modifySelectKit("select-kit")
        .onSelect((context, value) => {
          find(".on-select-test").html(value);
        });
    });

    this.set("content", [{ id: "1", name: "robin"}]);
  },

  test(assert) {
    expandSelectKit();

    selectKitSelectRow(1);

    andThen(() => {
      assert.equal(find(".on-select-test").html(), "1");
    });

    andThen(() => clearCallbacks());
  }
});

componentTest('with nameChanges', {
  template: '{{single-select content=content nameChanges=true}}',

  beforeEach() {
    this.set("robin", { id: "1", name: "robin"});
    this.set("content", [this.get("robin")]);
  },

  test(assert) {
    expandSelectKit();

    andThen(() => {
      assert.equal(selectKit().header.name(), "robin");
    });

    andThen(() => {
      this.set("robin.name", "robin2");
    });

    andThen(() => {
      assert.equal(selectKit().header.name(), "robin2");
    });
  }
});
