import componentTest from "helpers/component-test";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearCallbacks } from "select-kit/mixins/plugin-api";

moduleForComponent("single-select", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("updating the content refreshes the list", {
  template: "{{single-select value=1 content=content}}",

  beforeEach() {
    this.set("content", [{ id: 1, name: "BEFORE" }]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .rowByValue(1)
        .name(),
      "BEFORE"
    );

    await this.set("content", [{ id: 1, name: "AFTER" }]);

    assert.equal(
      this.get("subject")
        .rowByValue(1)
        .name(),
      "AFTER"
    );
  }
});

componentTest("accepts a value by reference", {
  template: "{{single-select value=value content=content}}",

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .selectedRow()
        .name(),
      "robin",
      "it highlights the row corresponding to the value"
    );

    await this.get("subject").selectRowByValue(1);

    assert.equal(this.get("value"), 1, "it mutates the value");
  }
});

componentTest("no default icon", {
  template: "{{single-select}}",

  test(assert) {
    assert.equal(
      this.get("subject")
        .header()
        .icon().length,
      0,
      "it doesn’t have an icon if not specified"
    );
  }
});

componentTest("default search icon", {
  template: "{{single-select filterable=true}}",

  async test(assert) {
    await this.get("subject").expand();

    assert.ok(
      exists(
        this.get("subject")
          .filter()
          .icon()
      ),
      "it has an icon"
    );
  }
});

componentTest("with no search icon", {
  template: "{{single-select filterable=true filterIcon=null}}",

  async test(assert) {
    await this.get("subject").expand();

    assert.notOk(
      exists(
        this.get("subject")
          .filter()
          .icon()
      ),
      "it has no icon"
    );
  }
});

componentTest("custom search icon", {
  template: '{{single-select filterable=true filterIcon="shower"}}',

  async test(assert) {
    await this.get("subject").expand();

    assert.ok(
      this.get("subject")
        .filter()
        .icon()
        .hasClass("d-icon-shower"),
      "it has a the correct icon"
    );
  }
});

componentTest("is expandable", {
  template: "{{single-select}}",
  async test(assert) {
    await this.get("subject").expand();

    assert.ok(this.get("subject").isExpanded());

    await this.get("subject").collapse();

    assert.notOk(this.get("subject").isExpanded());
  }
});

componentTest("accepts custom value/name keys", {
  template:
    '{{single-select value=value nameProperty="item" content=content valueAttribute="identifier"}}',

  beforeEach() {
    this.set("value", 1);
    this.set("content", [{ identifier: 1, item: "robin" }]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .selectedRow()
        .name(),
      "robin"
    );
  }
});

componentTest("doesn’t render collection content before first expand", {
  template: "{{single-select value=1 content=content}}",

  beforeEach() {
    this.set("content", [{ value: 1, name: "robin" }]);
  },

  async test(assert) {
    assert.notOk(exists(find(".select-kit-collection")));

    await this.get("subject").expand();

    assert.ok(exists(find(".select-kit-collection")));
  }
});

componentTest("dynamic headerText", {
  template: "{{single-select value=1 content=content}}",

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .header()
        .name(),
      "robin"
    );

    await this.get("subject").selectRowByValue(2);

    assert.equal(
      this.get("subject")
        .header()
        .name(),
      "regis",
      "it changes header text"
    );
  }
});

componentTest("supports custom row template", {
  template: "{{single-select content=content templateForRow=templateForRow}}",

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }]);
    this.set("templateForRow", rowComponent => {
      return `<b>${rowComponent.get("computedContent.name")}</b>`;
    });
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .rowByValue(1)
        .el()
        .html()
        .trim(),
      "<b>robin</b>"
    );
  }
});

componentTest("supports converting select value to integer", {
  template: "{{single-select value=value content=content castInteger=true}}",

  beforeEach() {
    this.set("value", 2);
    this.set("content", [
      { id: "1", name: "robin" },
      { id: "2", name: "régis" }
    ]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .selectedRow()
        .name(),
      "régis"
    );

    await this.set("value", 1);

    assert.equal(
      this.get("subject")
        .selectedRow()
        .name(),
      "robin",
      "it works with dynamic content"
    );
  }
});

componentTest("supports converting string as boolean to boolean", {
  template: "{{single-select value=value content=content castBoolean=true}}",

  beforeEach() {
    this.set("value", true);
    this.set("content", [
      { id: "true", name: "ASC" },
      { id: "false", name: "DESC" }
    ]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .selectedRow()
        .name(),
      "ASC"
    );

    await this.set("value", false);

    assert.equal(
      this.get("subject")
        .selectedRow()
        .name(),
      "DESC",
      "it works with dynamic content"
    );
  }
});

componentTest("supports keyboard events", {
  template: "{{single-select content=content filterable=true}}",

  beforeEach() {
    this.set("content", [{ id: 1, name: "robin" }, { id: 2, name: "regis" }]);
  },

  async test(assert) {
    await this.get("subject").expand();
    await this.get("subject").keyboard("down");

    assert.equal(
      this.get("subject")
        .highlightedRow()
        .title(),
      "regis",
      "the next row is highlighted"
    );

    await this.get("subject").keyboard("down");

    assert.equal(
      this.get("subject")
        .highlightedRow()
        .title(),
      "robin",
      "it returns to the first row"
    );

    await this.get("subject").keyboard("up");

    assert.equal(
      this.get("subject")
        .highlightedRow()
        .title(),
      "regis",
      "it highlights the last row"
    );

    await this.get("subject").keyboard("enter");

    assert.equal(
      this.get("subject")
        .selectedRow()
        .title(),
      "regis",
      "it selects the row when pressing enter"
    );
    assert.notOk(
      this.get("subject").isExpanded(),
      "it collapses the select box when selecting a row"
    );

    await this.get("subject").expand();
    await this.get("subject").keyboard("escape");

    assert.notOk(
      this.get("subject").isExpanded(),
      "it collapses the select box"
    );

    await this.get("subject").expand();
    await this.get("subject").fillInFilter("regis");
    await this.get("subject").keyboard("tab");

    assert.notOk(
      this.get("subject").isExpanded(),
      "it collapses the select box when selecting a row"
    );
  }
});

componentTest("with allowInitialValueMutation", {
  template:
    "{{single-select value=value content=content allowInitialValueMutation=true}}",

  beforeEach() {
    this.set("value", "");
    this.set("content", [
      { id: "1", name: "robin" },
      { id: "2", name: "régis" }
    ]);
  },

  test(assert) {
    assert.equal(
      this.get("value"),
      "1",
      "it mutates the value on initial rendering"
    );
  }
});

componentTest("support appending content through plugin api", {
  template: "{{single-select content=content}}",

  beforeEach() {
    withPluginApi("0.8.13", api => {
      api
        .modifySelectKit("select-kit")
        .appendContent([{ id: "2", name: "regis" }]);
    });

    this.set("content", [{ id: "1", name: "robin" }]);
  },
  async test(assert) {
    await this.get("subject").expand();

    assert.equal(this.get("subject").rows().length, 2);
    assert.equal(
      this.get("subject")
        .rowByIndex(1)
        .name(),
      "regis"
    );

    clearCallbacks();
  }
});

componentTest("support modifying content through plugin api", {
  template: "{{single-select content=content}}",

  beforeEach() {
    withPluginApi("0.8.13", api => {
      api
        .modifySelectKit("select-kit")
        .modifyContent((context, existingContent) => {
          existingContent.splice(1, 0, { id: "2", name: "sam" });
          return existingContent;
        });
    });

    this.set("content", [
      { id: "1", name: "robin" },
      { id: "3", name: "regis" }
    ]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(this.get("subject").rows().length, 3);
    assert.equal(
      this.get("subject")
        .rowByIndex(1)
        .name(),
      "sam"
    );

    clearCallbacks();
  }
});

componentTest("support prepending content through plugin api", {
  template: "{{single-select content=content}}",

  beforeEach() {
    withPluginApi("0.8.13", api => {
      api
        .modifySelectKit("select-kit")
        .prependContent([{ id: "2", name: "regis" }]);
    });

    this.set("content", [{ id: "1", name: "robin" }]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(this.get("subject").rows().length, 2);
    assert.equal(
      this.get("subject")
        .rowByIndex(0)
        .name(),
      "regis"
    );

    clearCallbacks();
  }
});

componentTest("support modifying on select behavior through plugin api", {
  template:
    '<span class="on-select-test"></span>{{single-select content=content}}',

  beforeEach() {
    withPluginApi("0.8.13", api => {
      api.modifySelectKit("select-kit").onSelect((context, value) => {
        find(".on-select-test").html(value);
      });
    });

    this.set("content", [
      { id: "1", name: "robin" },
      { id: "2", name: "arpit", __sk_row_type: "noopRow" }
    ]);
  },

  async test(assert) {
    await this.get("subject").expand();
    await this.get("subject").selectRowByValue(1);

    assert.equal(find(".on-select-test").html(), "1");

    await this.get("subject").expand();
    await this.get("subject").selectRowByValue(2);

    assert.equal(
      find(".on-select-test").html(),
      "2",
      "it calls onSelect for noopRows"
    );

    clearCallbacks();
  }
});

componentTest("support modifying on select none behavior through plugin api", {
  template:
    '<span class="on-select-none-test"></span>{{single-select none="none" content=content}}',

  beforeEach() {
    withPluginApi("0.8.25", api => {
      api.modifySelectKit("select-kit").onSelectNone(() => {
        find(".on-select-none-test").html("NONE");
      });
    });

    this.set("content", [{ id: "1", name: "robin" }]);
  },

  async test(assert) {
    await this.get("subject").expand();
    await this.get("subject").selectRowByValue(1);
    await this.get("subject").expand();
    await this.get("subject").selectNoneRow();

    assert.equal(find(".on-select-none-test").html(), "NONE");

    clearCallbacks();
  }
});

componentTest("with nameChanges", {
  template: "{{single-select content=content nameChanges=true}}",

  beforeEach() {
    this.set("robin", { id: "1", name: "robin" });
    this.set("content", [this.get("robin")]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .header()
        .name(),
      "robin"
    );

    await this.set("robin.name", "robin2");

    assert.equal(
      this.get("subject")
        .header()
        .name(),
      "robin2"
    );
  }
});

componentTest("with null value", {
  template: "{{single-select content=content}}",

  beforeEach() {
    this.set("content", [{ name: "robin" }]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .header()
        .name(),
      "robin"
    );
    assert.equal(
      this.get("subject")
        .header()
        .value(),
      undefined
    );
  }
});

componentTest("with collection header", {
  template: "{{single-select collectionHeader=collectionHeader}}",

  beforeEach() {
    this.set("collectionHeader", "<h2>Hello</h2>");
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.ok(exists(".collection-header h2"));
  }
});

componentTest("with title", {
  template: '{{single-select title=(i18n "test.title")}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { title: "My title" };
  },

  test(assert) {
    assert.equal(
      this.get("subject")
        .header()
        .title(),
      "My title"
    );
  }
});

componentTest("support modifying header computed content through plugin api", {
  template: "{{single-select content=content}}",

  beforeEach() {
    withPluginApi("0.8.15", api => {
      api
        .modifySelectKit("select-kit")
        .modifyHeaderComputedContent((context, computedContent) => {
          computedContent.title = "Not so evil";
          return computedContent;
        });
    });

    this.set("content", [{ id: "1", name: "robin" }]);
  },

  test(assert) {
    assert.equal(
      this.get("subject")
        .header()
        .title(),
      "Not so evil"
    );

    clearCallbacks();
  }
});

componentTest("with limitMatches", {
  template: "{{single-select content=content limitMatches=2}}",

  beforeEach() {
    this.set("content", ["sam", "jeff", "neil"]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject")
        .el()
        .find(".select-kit-row").length,
      2
    );
  }
});

componentTest("with minimum", {
  template:
    "{{single-select content=content minimum=1 allowAutoSelectFirst=false}}",

  beforeEach() {
    this.set("content", ["sam", "jeff", "neil"]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(
      this.get("subject").validationMessage(),
      "Select at least 1 item."
    );

    await this.get("subject").selectRowByValue("sam");

    assert.equal(
      this.get("subject")
        .header()
        .label(),
      "sam"
    );
  }
});

componentTest("with minimumLabel", {
  template:
    '{{single-select content=content minimum=1 minimumLabel="test.minimum" allowAutoSelectFirst=false}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { minimum: "min %{count}" };
    this.set("content", ["sam", "jeff", "neil"]);
  },

  async test(assert) {
    await this.get("subject").expand();

    assert.equal(this.get("subject").validationMessage(), "min 1");

    await this.get("subject").selectRowByValue("jeff");

    assert.equal(
      this.get("subject")
        .header()
        .label(),
      "jeff"
    );
  }
});

componentTest("with accents in filter", {
  template: "{{single-select content=content filterable=true}}",

  beforeEach() {
    this.set("content", ["sam", "jeff", "neil"]);
  },

  async test(assert) {
    await this.get("subject").expand();
    await this.get("subject").fillInFilter("jéff");

    assert.equal(this.get("subject").rows().length, 1);
    assert.equal(
      this.get("subject")
        .rowByIndex(0)
        .name(),
      "jeff"
    );
  }
});

componentTest("with accents in content", {
  template: "{{single-select content=content filterable=true}}",

  beforeEach() {
    this.set("content", ["sam", "jéff", "neil"]);
  },

  async test(assert) {
    await this.get("subject").expand();
    await this.get("subject").fillInFilter("jeff");

    assert.equal(this.get("subject").rows().length, 1);
    assert.equal(
      this.get("subject")
        .rowByIndex(0)
        .name(),
      "jéff"
    );
  }
});

componentTest("with no content and allowAny", {
  template: "{{single-select allowAny=true}}",

  async test(assert) {
    await click(
      this.get("subject")
        .header()
        .el()
    );

    const $filter = this.get("subject")
      .filter()
      .el();

    assert.ok($filter.hasClass("is-focused"));
    assert.ok(!$filter.hasClass("is-hidden"));
  }
});

componentTest("with forceEscape", {
  template: "{{single-select content=content forceEscape=true}}",

  beforeEach() {
    this.set("content", ["<div>sam</div>"]);
  },

  async test(assert) {
    await this.get("subject").expand();

    const row = this.get("subject").rowByIndex(0);
    assert.equal(
      row
        .el()
        .find(".name")
        .html()
        .trim(),
      "&lt;div&gt;sam&lt;/div&gt;"
    );

    assert.equal(
      this.get("subject")
        .header()
        .el()
        .find(".selected-name")
        .html()
        .trim(),
      "&lt;div&gt;sam&lt;/div&gt;"
    );
  }
});

componentTest("without forceEscape", {
  template: "{{single-select content=content forceEscape=false}}",

  beforeEach() {
    this.set("content", ["<div>sam</div>"]);
  },

  async test(assert) {
    await this.get("subject").expand();

    const row = this.get("subject").rowByIndex(0);
    assert.equal(
      row
        .el()
        .find(".name")
        .html()
        .trim(),
      "<div>sam</div>"
    );

    assert.equal(
      this.get("subject")
        .header()
        .el()
        .find(".selected-name")
        .html()
        .trim(),
      "<div>sam</div>"
    );
  }
});

componentTest("onSelect", {
  template:
    "<div class='test-external-action'></div>{{single-select content=content onSelect=(action externalAction)}}",

  beforeEach() {
    this.set("externalAction", actual => {
      find(".test-external-action").text(actual);
    });

    this.set("content", ["red", "blue"]);
  },

  async test(assert) {
    await this.get("subject").expand();
    await this.get("subject").selectRowByValue("red");

    assert.equal(
      find(".test-external-action")
        .text()
        .trim(),
      "red"
    );
  }
});

componentTest("onDeselect", {
  template:
    "<div class='test-external-action'></div>{{single-select content=content onDeselect=(action externalAction)}}",

  beforeEach() {
    this.set("externalAction", actual => {
      find(".test-external-action").text(actual);
    });

    this.set("content", ["red", "blue"]);
  },

  async test(assert) {
    await this.get("subject").expand();
    await this.get("subject").selectRowByValue("red");
    await this.get("subject").expand();
    await this.get("subject").selectRowByValue("blue");

    assert.equal(
      find(".test-external-action")
        .text()
        .trim(),
      "red"
    );
  }
});

componentTest("noopRow", {
  template: "{{single-select value=value content=content}}",

  beforeEach() {
    this.set("value", "blue");
    this.set("content", [
      { id: "red", name: "Red", __sk_row_type: "noopRow" },
      "blue",
      "green"
    ]);
  },

  async test(assert) {
    await this.get("subject").expand();
    await this.get("subject").selectRowByValue("red");
    assert.equal(this.get("value"), "blue", "it doesn’t change the value");

    await this.get("subject").expand();
    await this.get("subject").selectRowByValue("green");
    assert.equal(this.get("value"), "green");
  }
});
