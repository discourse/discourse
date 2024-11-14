import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

const DEFAULT_CONTENT = {
  content: [
    { id: 1, label: "foo" },
    { id: 2, translatedLabel: "FooBar" },
    "separator",
    { id: 3, translatedLabel: "With icon", icon: "xmark" },
    { id: 4, html: "<b>baz</b>" },
    { id: 5, translatedLabel: "Disabled", disabled: true },
  ],
  label: "foo",
};

async function clickRowById(id) {
  await click(`#my-dropdown .widget-dropdown-item.item-${id}`);
}

function rowById(id) {
  return query(`#my-dropdown .widget-dropdown-item.item-${id}`);
}

async function toggle() {
  await click("#my-dropdown .widget-dropdown-header");
}

function headerLabel() {
  return query("#my-dropdown .widget-dropdown-header .label").innerText.trim();
}

function header() {
  return query("#my-dropdown .widget-dropdown-header");
}

function body() {
  return query("#my-dropdown .widget-dropdown-body");
}

const TEMPLATE = hbs`
  <MountWidget
    @widget="widget-dropdown"
    @args={{hash
      id="my-dropdown"
      icon=this.icon
      label=this.label
      class=this.class
      translatedLabel=this.translatedLabel
      content=this.content
      options=this.options
    }}
  />
`;

module("Integration | Component | Widget | widget-dropdown", function (hooks) {
  setupRenderingTest(hooks);

  let _translations = I18n.translations;

  hooks.afterEach(function () {
    I18n.translations = _translations;
  });

  test("dropdown id", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    assert.dom("#my-dropdown").exists();
  });

  test("label", async function (assert) {
    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    assert.strictEqual(headerLabel(), "FooBaz");
  });

  test("translatedLabel", async function (assert) {
    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);
    this.set("translatedLabel", "BazFoo");

    await render(TEMPLATE);

    assert.strictEqual(headerLabel(), this.translatedLabel);
  });

  test("content", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    await toggle();
    assert.strictEqual(rowById(1).dataset.id, "1", "it creates rows");
    assert.strictEqual(rowById(2).dataset.id, "2", "it creates rows");
    assert.strictEqual(rowById(3).dataset.id, "3", "it creates rows");
  });

  test("onChange action", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);
    this.set("onChange", (item) => (query("#test").innerText = item.id));

    await render(hbs`
      <div id="test"></div>

      <MountWidget
        @widget="widget-dropdown"
        @args={{hash
          id="my-dropdown"
          label=this.label
          content=this.content
          onChange=this.onChange
        }}
      />
    `);

    await toggle();
    await clickRowById(2);
    assert.dom("#test").hasText("2", "it calls the onChange actions");
  });

  test("can be opened and closed", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    assert.dom("#my-dropdown.closed").exists();
    assert.dom("#my-dropdown .widget-dropdown-body").doesNotExist();
    await toggle();
    assert.strictEqual(rowById(2).innerText.trim(), "FooBar");
    assert.dom("#my-dropdown.opened").exists();
    assert.dom("#my-dropdown .widget-dropdown-body").exists();
    await toggle();
    assert.dom("#my-dropdown.closed").exists();
    assert.dom("#my-dropdown .widget-dropdown-body").doesNotExist();
  });

  test("icon", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);
    this.set("icon", "xmark");

    await render(TEMPLATE);

    assert.dom(".d-icon-xmark", header()).exists();
  });

  test("class", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);
    this.set("class", "activated");

    await render(TEMPLATE);

    assert.dom("#my-dropdown.activated").exists();
  });

  test("content with translatedLabel", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    await toggle();
    assert.strictEqual(rowById(2).innerText.trim(), "FooBar");
  });

  test("content with label", async function (assert) {
    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    await toggle();
    assert.strictEqual(rowById(1).innerText.trim(), "FooBaz");
  });

  test("content with icon", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    await toggle();
    assert.dom(".d-icon-xmark", rowById(3)).exists();
  });

  test("content with html", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);
    await toggle();

    assert.dom(rowById(4)).hasHtml("<span><b>baz</b></span>");
  });

  test("separator", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    await toggle();
    assert
      .dom("#my-dropdown .widget-dropdown-item:nth-child(3)")
      .hasClass("separator");
  });

  test("hides widget if no content", async function (assert) {
    this.setProperties({ content: null, label: "foo" });

    await render(TEMPLATE);

    assert.dom("#my-dropdown .widget-dropdown-header").doesNotExist();
    assert.dom("#my-dropdown .widget-dropdown-body").doesNotExist();
  });

  test("headerClass option", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { headerClass: "btn-small and-text" });

    await render(TEMPLATE);

    assert.dom(header()).hasClass("widget-dropdown-header");
    assert.dom(header()).hasClass("btn-small");
    assert.dom(header()).hasClass("and-text");
  });

  test("bodyClass option", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { bodyClass: "gigantic and-yet-small" });

    await render(TEMPLATE);

    await toggle();
    assert.dom(body()).hasClass("widget-dropdown-body");
    assert.dom(body()).hasClass("gigantic");
    assert.dom(body()).hasClass("and-yet-small");
  });

  test("caret option", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { caret: true });

    await render(TEMPLATE);

    assert
      .dom("#my-dropdown .widget-dropdown-header .d-icon-caret-down")
      .exists();
  });

  test("disabled widget", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { disabled: true });

    await render(TEMPLATE);

    assert.dom("#my-dropdown.disabled").exists();

    await toggle();
    assert.strictEqual(rowById(1), null, "it does not display options");
  });

  test("disabled item", async function (assert) {
    this.setProperties(DEFAULT_CONTENT);

    await render(TEMPLATE);

    await toggle();
    assert.dom(".widget-dropdown-item.item-5.disabled").exists();
  });
});
