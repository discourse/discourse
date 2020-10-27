import { exists } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import {
  moduleForWidget,
  widgetTest,
} from "discourse/tests/helpers/widget-test";
import { click } from "@ember/test-helpers";

moduleForWidget("widget-dropdown");

const DEFAULT_CONTENT = {
  content: [
    { id: 1, label: "foo" },
    { id: 2, translatedLabel: "FooBar" },
    "separator",
    { id: 3, translatedLabel: "With icon", icon: "times" },
    { id: 4, html: "<b>baz</b>" },
  ],
  label: "foo",
};

async function clickRowById(id) {
  await click(`#my-dropdown .widget-dropdown-item.item-${id}`);
}

function rowById(id) {
  return find(`#my-dropdown .widget-dropdown-item.item-${id}`)[0];
}

async function toggle() {
  await click("#my-dropdown .widget-dropdown-header");
}

function headerLabel() {
  return find(
    "#my-dropdown .widget-dropdown-header .label"
  )[0].innerText.trim();
}

function header() {
  return find("#my-dropdown .widget-dropdown-header")[0];
}

function body() {
  return find("#my-dropdown .widget-dropdown-body")[0];
}

const TEMPLATE = `
  {{mount-widget
    widget="widget-dropdown"
    args=(hash
      id="my-dropdown"
      icon=icon
      label=label
      class=class
      translatedLabel=translatedLabel
      content=content
      options=options
    )
}}`;

widgetTest("dropdown id", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
  },

  test(assert) {
    assert.ok(exists("#my-dropdown"));
  },
});

widgetTest("label", {
  template: TEMPLATE,

  _translations: I18n.translations,

  beforeEach() {
    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);
  },

  afterEach() {
    I18n.translations = this._translations;
  },

  test(assert) {
    assert.equal(headerLabel(), "FooBaz");
  },
});

widgetTest("translatedLabel", {
  template: TEMPLATE,

  _translations: I18n.translations,

  beforeEach() {
    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);
    this.set("translatedLabel", "BazFoo");
  },

  afterEach() {
    I18n.translations = this._translations;
  },

  test(assert) {
    assert.equal(headerLabel(), this.translatedLabel);
  },
});

widgetTest("content", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
  },

  async test(assert) {
    await toggle();
    assert.equal(rowById(1).dataset.id, 1, "it creates rows");
    assert.equal(rowById(2).dataset.id, 2, "it creates rows");
    assert.equal(rowById(3).dataset.id, 3, "it creates rows");
  },
});

widgetTest("onChange action", {
  template: `
    <div id="test"></div>
    {{mount-widget
      widget="widget-dropdown"
      args=(hash
        id="my-dropdown"
        label=label
        content=content
        onChange=(action "onChange")
      )
    }}
  `,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);

    this.on(
      "onChange",
      (item) => (this._element.querySelector("#test").innerText = item.id)
    );
  },

  async test(assert) {
    await toggle();
    await clickRowById(2);
    assert.equal(find("#test").text(), 2, "it calls the onChange actions");
  },
});

widgetTest("can be opened and closed", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
  },

  async test(assert) {
    assert.ok(exists("#my-dropdown.closed"));
    assert.ok(!exists("#my-dropdown .widget-dropdown-body"));
    await toggle();
    assert.equal(rowById(2).innerText.trim(), "FooBar");
    assert.ok(exists("#my-dropdown.opened"));
    assert.ok(exists("#my-dropdown .widget-dropdown-body"));
    await toggle();
    assert.ok(exists("#my-dropdown.closed"));
    assert.ok(!exists("#my-dropdown .widget-dropdown-body"));
  },
});

widgetTest("icon", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
    this.set("icon", "times");
  },

  test(assert) {
    assert.ok(exists(header().querySelector(".d-icon-times")));
  },
});

widgetTest("class", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
    this.set("class", "activated");
  },

  test(assert) {
    assert.ok(exists("#my-dropdown.activated"));
  },
});

widgetTest("content with translatedLabel", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
  },

  async test(assert) {
    await toggle();
    assert.equal(rowById(2).innerText.trim(), "FooBar");
  },
});

widgetTest("content with label", {
  template: TEMPLATE,

  _translations: I18n.translations,

  beforeEach() {
    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);
  },

  afterEach() {
    I18n.translations = this._translations;
  },

  async test(assert) {
    await toggle();
    assert.equal(rowById(1).innerText.trim(), "FooBaz");
  },
});

widgetTest("content with icon", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
  },

  async test(assert) {
    await toggle();
    assert.ok(exists(rowById(3).querySelector(".d-icon-times")));
  },
});

widgetTest("content with html", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
  },

  async test(assert) {
    await toggle();
    assert.equal(rowById(4).innerHTML.trim(), "<span><b>baz</b></span>");
  },
});

widgetTest("separator", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
  },

  async test(assert) {
    await toggle();
    assert.ok(
      find(
        "#my-dropdown .widget-dropdown-item:nth-child(3)"
      )[0].classList.contains("separator")
    );
  },
});

widgetTest("hides widget if no content", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties({ content: null, label: "foo" });
  },

  test(assert) {
    assert.notOk(exists("#my-dropdown .widget-dropdown-header"));
    assert.notOk(exists("#my-dropdown .widget-dropdown-body"));
  },
});

widgetTest("headerClass option", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { headerClass: "btn-small and-text" });
  },

  test(assert) {
    assert.ok(header().classList.contains("widget-dropdown-header"));
    assert.ok(header().classList.contains("btn-small"));
    assert.ok(header().classList.contains("and-text"));
  },
});

widgetTest("bodyClass option", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { bodyClass: "gigantic and-yet-small" });
  },

  async test(assert) {
    await toggle();
    assert.ok(body().classList.contains("widget-dropdown-body"));
    assert.ok(body().classList.contains("gigantic"));
    assert.ok(body().classList.contains("and-yet-small"));
  },
});

widgetTest("caret option", {
  template: TEMPLATE,

  beforeEach() {
    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { caret: true });
  },

  test(assert) {
    assert.ok(
      exists("#my-dropdown .widget-dropdown-header .d-icon-caret-down")
    );
  },
});
