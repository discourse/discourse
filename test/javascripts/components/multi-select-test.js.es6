import componentTest from "helpers/component-test";
import { withPluginApi } from "discourse/lib/plugin-api";
import { clearCallbacks } from "select-kit/mixins/plugin-api";

moduleForComponent("multi-select", {
  integration: true,
  beforeEach: function() {
    this.set("subject", selectKit());
  }
});

componentTest("with objects and values", {
  template: "{{multi-select content=items values=values}}",

  beforeEach() {
    this.set("items", [{ id: 1, name: "hello" }, { id: 2, name: "world" }]);
    this.set("values", [1, 2]);
  },

  test(assert) {
    assert.equal(this.subject.header().value(), "1,2");
  }
});

componentTest("with title", {
  template: '{{multi-select title=(i18n "test.title")}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { title: "My title" };
  },

  test(assert) {
    assert.equal(
      selectKit()
        .header()
        .title(),
      "My title"
    );
  }
});

componentTest("interactions", {
  template: "{{multi-select none=none content=items values=values}}",

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { none: "none" };
    this.set("items", [
      { id: 1, name: "regis" },
      { id: 2, name: "sam" },
      { id: 3, name: "robin" }
    ]);
    this.set("values", [1, 2]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(
      this.subject.highlightedRow().name(),
      "robin",
      "it highlights the first content row"
    );

    await this.set("none", "test.none");

    assert.ok(this.subject.noneRow().exists());
    assert.equal(
      this.subject.highlightedRow().name(),
      "robin",
      "it highlights the first content row"
    );

    await this.subject.selectRowByValue(3);
    await this.subject.expand();

    assert.equal(
      this.subject.highlightedRow().name(),
      "none",
      "it highlights none row if no content"
    );

    await this.subject.fillInFilter("joffrey");

    assert.equal(
      this.subject.highlightedRow().name(),
      "joffrey",
      "it highlights create row when filling filter"
    );

    await this.subject.keyboard("enter");

    assert.equal(
      this.subject.highlightedRow().name(),
      "none",
      "it highlights none row after creating content and no content left"
    );

    await this.subject.keyboard("backspace");

    const $lastSelectedName = this.subject
      .header()
      .el()
      .find(".selected-name")
      .last();
    assert.equal($lastSelectedName.attr("data-name"), "joffrey");
    assert.ok(
      $lastSelectedName.hasClass("is-highlighted"),
      "it highlights the last selected name when using backspace"
    );

    await this.subject.keyboard("backspace");

    const $lastSelectedName1 = this.subject
      .header()
      .el()
      .find(".selected-name")
      .last();
    assert.equal(
      $lastSelectedName1.attr("data-name"),
      "robin",
      "it removes the previous highlighted selected content"
    );
    assert.notOk(
      this.subject.rowByValue("joffrey").exists(),
      "generated content shouldn’t appear in content when removed"
    );

    await this.subject.keyboard("selectAll");

    const $highlightedSelectedNames2 = this.subject
      .header()
      .el()
      .find(".selected-name.is-highlighted");
    assert.equal(
      $highlightedSelectedNames2.length,
      3,
      "it highlights each selected name"
    );

    await this.subject.keyboard("backspace");

    const $selectedNames = this.subject
      .header()
      .el()
      .find(".selected-name");
    assert.equal($selectedNames.length, 0, "it removed all selected content");

    assert.ok(this.subject.isFocused());
    assert.ok(this.subject.isExpanded());

    await this.subject.keyboard("escape");

    assert.ok(this.subject.isFocused());
    assert.notOk(this.subject.isExpanded());

    await this.subject.keyboard("escape");

    assert.notOk(this.subject.isFocused());
    assert.notOk(this.subject.isExpanded());
  }
});

componentTest("with limitMatches", {
  template: "{{multi-select content=content limitMatches=2}}",

  beforeEach() {
    this.set("content", ["sam", "jeff", "neil"]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(this.subject.el().find(".select-kit-row").length, 2);
  }
});

componentTest("with minimum", {
  template: "{{multi-select content=content minimum=1}}",

  beforeEach() {
    this.set("content", ["sam", "jeff", "neil"]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(this.subject.validationMessage(), "Select at least 1 item.");

    await this.subject.selectRowByValue("sam");

    assert.equal(this.subject.header().label(), "sam");
  }
});

componentTest("with minimumLabel", {
  template:
    '{{multi-select content=content minimum=1 minimumLabel="test.minimum"}}',

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { minimum: "min %{count}" };
    this.set("content", ["sam", "jeff", "neil"]);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(this.subject.validationMessage(), "min 1");

    await this.subject.selectRowByValue("jeff");

    assert.equal(this.subject.header().label(), "jeff");
  }
});

componentTest("with forceEscape", {
  template: "{{multi-select content=content forceEscape=true}}",

  beforeEach() {
    this.set("content", ["<div>sam</div>"]);
  },
  skip: true,
  async test(assert) {
    await this.subject.expand();

    const row = this.subject.rowByIndex(0);
    assert.equal(
      row
        .el()
        .find(".name")
        .html()
        .trim(),
      "&lt;div&gt;sam&lt;/div&gt;"
    );

    await this.subject.fillInFilter("<div>jeff</div>");
    await this.subject.keyboard("enter");

    assert.equal(
      this.subject
        .header()
        .el()
        .find(".name")
        .html()
        .trim(),
      "&lt;div&gt;jeff&lt;/div&gt;"
    );
  }
});

componentTest("with forceEscape", {
  template: "{{multi-select content=content forceEscape=false}}",

  beforeEach() {
    this.set("content", ["<div>sam</div>"]);
  },

  async test(assert) {
    await this.subject.expand();

    const row = this.subject.rowByIndex(0);
    assert.equal(
      row
        .el()
        .find(".name")
        .html()
        .trim(),
      "<div>sam</div>"
    );

    await this.subject.fillInFilter("<div>jeff</div>");
    await this.subject.keyboard("enter");

    assert.equal(
      this.subject
        .header()
        .el()
        .find(".name")
        .html()
        .trim(),
      "<div>jeff</div>"
    );
  }
});

componentTest("support modifying on select behavior through plugin api", {
  template:
    '<span class="on-select-test"></span>{{multi-select content=content}}',

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
    await this.subject.expand();
    await this.subject.selectRowByValue(1);

    assert.equal(find(".on-select-test").html(), "1");

    await this.subject.expand();
    await this.subject.selectRowByValue(2);

    assert.equal(
      find(".on-select-test").html(),
      "2",
      "it calls onSelect for noopRows"
    );

    clearCallbacks();
  }
});
