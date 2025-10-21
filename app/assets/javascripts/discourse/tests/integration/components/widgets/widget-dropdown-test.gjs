import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
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

module("Integration | Component | Widget | widget-dropdown", function (hooks) {
  setupRenderingTest(hooks);

  let _translations = I18n.translations;

  hooks.beforeEach(function () {
    this.siteSettings.deactivate_widgets_rendering = false;
  });

  hooks.afterEach(function () {
    I18n.translations = _translations;
  });

  test("dropdown id", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown").exists();
  });

  test("label", async function (assert) {
    const self = this;

    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown .widget-dropdown-header .label").hasText("FooBaz");
  });

  test("translatedLabel", async function (assert) {
    const self = this;

    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);
    this.set("translatedLabel", "BazFoo");

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown .widget-dropdown-header .label").hasText("BazFoo");
  });

  test("content", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    await click("#my-dropdown .widget-dropdown-header");
    assert
      .dom("#my-dropdown .widget-dropdown-item.item-1")
      .hasAttribute("data-id", "1", "creates rows");
    assert
      .dom("#my-dropdown .widget-dropdown-item.item-2")
      .hasAttribute("data-id", "2", "creates rows");
    assert
      .dom("#my-dropdown .widget-dropdown-item.item-3")
      .hasAttribute("data-id", "3", "creates rows");
  });

  test("onChange action", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);
    this.set("onChange", (item) => assert.step(`${item.id}`));

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            label=self.label
            content=self.content
            onChange=self.onChange
          }}
        />
      </template>
    );

    await click("#my-dropdown .widget-dropdown-header");
    await click("#my-dropdown .widget-dropdown-item.item-2");
    assert.verifySteps(["2"], "calls the onChange actions");
  });

  test("can be opened and closed", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown.closed").exists();
    assert.dom("#my-dropdown .widget-dropdown-body").doesNotExist();
    await click("#my-dropdown .widget-dropdown-header");
    assert.dom("#my-dropdown .widget-dropdown-item.item-2").hasText("FooBar");
    assert.dom("#my-dropdown.opened").exists();
    assert.dom("#my-dropdown .widget-dropdown-body").exists();
    await click("#my-dropdown .widget-dropdown-header");
    assert.dom("#my-dropdown.closed").exists();
    assert.dom("#my-dropdown .widget-dropdown-body").doesNotExist();
  });

  test("icon", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);
    this.set("icon", "xmark");

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown .widget-dropdown-header .d-icon-xmark").exists();
  });

  test("class", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);
    this.set("class", "activated");

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown.activated").exists();
  });

  test("content with translatedLabel", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    await click("#my-dropdown .widget-dropdown-header");
    assert.dom("#my-dropdown .widget-dropdown-item.item-2").hasText("FooBar");
  });

  test("content with label", async function (assert) {
    const self = this;

    I18n.translations = { en: { js: { foo: "FooBaz" } } };
    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    await click("#my-dropdown .widget-dropdown-header");
    assert.dom("#my-dropdown .widget-dropdown-item.item-1").hasText("FooBaz");
  });

  test("content with icon", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    await click("#my-dropdown .widget-dropdown-header");
    assert
      .dom("#my-dropdown .widget-dropdown-item.item-3 .d-icon-xmark")
      .exists();
  });

  test("content with html", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );
    await click("#my-dropdown .widget-dropdown-header");

    assert
      .dom("#my-dropdown .widget-dropdown-item.item-4")
      .hasHtml("<span><b>baz</b></span>");
  });

  test("separator", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    await click("#my-dropdown .widget-dropdown-header");
    assert
      .dom("#my-dropdown .widget-dropdown-item:nth-child(3)")
      .hasClass("separator");
  });

  test("hides widget if no content", async function (assert) {
    const self = this;

    this.setProperties({ content: null, label: "foo" });

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown .widget-dropdown-header").doesNotExist();
    assert.dom("#my-dropdown .widget-dropdown-body").doesNotExist();
  });

  test("headerClass option", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { headerClass: "btn-small and-text" });

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown .widget-dropdown-header").hasClass("btn-small");
    assert.dom("#my-dropdown .widget-dropdown-header").hasClass("and-text");
  });

  test("bodyClass option", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { bodyClass: "gigantic and-yet-small" });

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    await click("#my-dropdown .widget-dropdown-header");
    assert.dom("#my-dropdown .widget-dropdown-body").hasClass("gigantic");
    assert.dom("#my-dropdown .widget-dropdown-body").hasClass("and-yet-small");
  });

  test("caret option", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { caret: true });

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert
      .dom("#my-dropdown .widget-dropdown-header .d-icon-caret-down")
      .exists();
  });

  test("disabled widget", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);
    this.set("options", { disabled: true });

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    assert.dom("#my-dropdown.disabled").exists();

    await click("#my-dropdown .widget-dropdown-header");
    assert
      .dom("#my-dropdown .widget-dropdown-item.item-1")
      .doesNotExist("does not display options");
  });

  test("disabled item", async function (assert) {
    const self = this;

    this.setProperties(DEFAULT_CONTENT);

    await render(
      <template>
        <MountWidget
          @widget="widget-dropdown"
          @args={{hash
            id="my-dropdown"
            icon=self.icon
            label=self.label
            class=self.class
            translatedLabel=self.translatedLabel
            content=self.content
            options=self.options
          }}
        />
      </template>
    );

    await click("#my-dropdown .widget-dropdown-header");
    assert.dom(".widget-dropdown-item.item-5.disabled").exists();
  });
});
