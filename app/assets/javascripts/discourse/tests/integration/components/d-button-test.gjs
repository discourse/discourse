import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DButton from "discourse/components/d-button";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n, { i18n } from "discourse-i18n";

module("Integration | Component | d-button", function (hooks) {
  setupRenderingTest(hooks);

  test("icon only button", async function (assert) {
    await render(<template><DButton @icon="plus" tabindex="3" /></template>);

    assert.dom("button.btn.btn-icon.no-text").exists("has all the classes");
    assert.dom("button .d-icon.d-icon-plus").exists("has the icon");
    assert.dom("button").hasAttribute("tabindex", "3", "has the tabindex");
  });

  test("icon and text button", async function (assert) {
    await render(
      <template><DButton @icon="plus" @label="topic.create" /></template>
    );

    assert.dom("button.btn.btn-icon-text").exists("has all the classes");
    assert.dom("button .d-icon.d-icon-plus").exists("has the icon");
    assert.dom("button span.d-button-label").exists("has the label");
  });

  test("text only button", async function (assert) {
    await render(<template><DButton @label="topic.create" /></template>);

    assert.dom("button.btn.btn-text").exists("has all the classes");
    assert.dom("button span.d-button-label").exists("has the label");
  });

  test("form attribute", async function (assert) {
    await render(<template><DButton @form="login-form" /></template>);

    assert.dom("button[form=login-form]").exists("has the form attribute");
  });

  test("link-styled button", async function (assert) {
    await render(<template><DButton @display="link" /></template>);

    assert.dom("button.btn-link:not(.btn)").exists("has the right classes");
  });

  test("isLoading button", async function (assert) {
    const self = this;

    this.set("isLoading", true);

    await render(
      <template><DButton @isLoading={{self.isLoading}} /></template>
    );

    assert
      .dom("button.is-loading .loading-icon")
      .exists("has a spinner showing");
    assert.dom("button").isDisabled("while loading the button is disabled");

    this.set("isLoading", false);

    assert
      .dom("button .loading-icon")
      .doesNotExist("doesn't have a spinner showing");
    assert.dom("button").isEnabled("while not loading the button is enabled");
  });

  test("button without isLoading attribute", async function (assert) {
    await render(<template><DButton /></template>);

    assert
      .dom("button.is-loading")
      .doesNotExist("doesn't have class is-loading");
    assert
      .dom("button .loading-icon")
      .doesNotExist("doesn't have a spinner showing");
    assert.dom("button").isNotDisabled();
  });

  test("isLoading button explicitly set to undefined state", async function (assert) {
    await render(<template><DButton @isLoading={{undefined}} /></template>);

    assert
      .dom("button.is-loading")
      .doesNotExist("doesn't have class is-loading");
    assert
      .dom("button .loading-icon")
      .doesNotExist("doesn't have a spinner showing");
    assert.dom("button").isNotDisabled();
  });

  test("disabled button", async function (assert) {
    const self = this;

    this.set("disabled", true);

    await render(<template><DButton @disabled={{self.disabled}} /></template>);

    assert.dom("button").isDisabled();

    this.set("disabled", false);
    assert.dom("button").isEnabled();
  });

  test("aria-label", async function (assert) {
    const self = this;

    I18n.translations[I18n.locale].js.test = { fooAriaLabel: "foo" };

    await render(
      <template>
        <DButton
          @ariaLabel={{self.ariaLabel}}
          @translatedAriaLabel={{self.translatedAriaLabel}}
        />
      </template>
    );

    this.set("ariaLabel", "test.fooAriaLabel");

    assert.dom("button").hasAria("label", i18n("test.fooAriaLabel"));

    this.setProperties({
      ariaLabel: null,
      translatedAriaLabel: "bar",
    });

    assert.dom("button").hasAria("label", "bar");
  });

  test("title", async function (assert) {
    const self = this;

    I18n.translations[I18n.locale].js.test = { fooTitle: "foo" };

    await render(
      <template>
        <DButton
          @title={{self.title}}
          @translatedTitle={{self.translatedTitle}}
        />
      </template>
    );

    this.set("title", "test.fooTitle");
    assert.dom("button").hasAttribute("title", i18n("test.fooTitle"));

    this.setProperties({
      title: null,
      translatedTitle: "bar",
    });

    assert.dom("button").hasAttribute("title", "bar");
  });

  test("label", async function (assert) {
    const self = this;

    I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };

    await render(
      <template>
        <DButton
          @label={{self.label}}
          @translatedLabel={{self.translatedLabel}}
        />
      </template>
    );

    this.set("label", "test.fooLabel");

    assert.dom("button .d-button-label").hasText(i18n("test.fooLabel"));

    this.setProperties({
      label: null,
      translatedLabel: "bar",
    });

    assert.dom("button .d-button-label").hasText("bar");
  });

  test("aria-expanded", async function (assert) {
    const self = this;

    await render(
      <template><DButton @ariaExpanded={{self.ariaExpanded}} /></template>
    );

    assert.dom("button").doesNotHaveAria("expanded");

    this.set("ariaExpanded", true);
    assert.dom("button").hasAria("expanded", "true");

    this.set("ariaExpanded", false);
    assert.dom("button").hasAria("expanded", "false");

    this.set("ariaExpanded", "false");
    assert.dom("button").doesNotHaveAria("expanded");

    this.set("ariaExpanded", "true");
    assert.dom("button").doesNotHaveAria("expanded");
  });

  test("aria-controls", async function (assert) {
    const self = this;

    await render(
      <template><DButton @ariaControls={{self.ariaControls}} /></template>
    );

    this.set("ariaControls", "foo-bar");
    assert.dom("button").hasAria("controls", "foo-bar");
  });

  test("onKeyDown callback", async function (assert) {
    const self = this;

    this.set("foo", null);
    this.set("onKeyDown", () => {
      this.set("foo", "bar");
    });
    this.set("action", () => {
      this.set("foo", "baz");
    });

    await render(
      <template>
        <DButton @action={{self.action}} @onKeyDown={{self.onKeyDown}} />
      </template>
    );

    await triggerKeyEvent(".btn", "keydown", "Space");
    assert.strictEqual(this.foo, "bar");

    await triggerKeyEvent(".btn", "keydown", "Enter");
    assert.strictEqual(this.foo, "bar");
  });

  test("press Enter", async function (assert) {
    const self = this;

    this.set("foo", null);
    this.set("action", () => {
      this.set("foo", "bar");
    });

    await render(<template><DButton @action={{self.action}} /></template>);

    await triggerKeyEvent(".btn", "keydown", "Space");
    assert.strictEqual(this.foo, null);

    await triggerKeyEvent(".btn", "keydown", "Enter");
    assert.strictEqual(this.foo, "bar");
  });

  test("@action function is triggered on click", async function (assert) {
    const self = this;

    this.set("foo", null);
    this.set("action", () => {
      this.set("foo", "bar");
    });

    await render(<template><DButton @action={{self.action}} /></template>);

    await click(".btn");

    assert.strictEqual(this.foo, "bar");
  });

  test("ellipses", async function (assert) {
    await render(
      <template>
        <DButton @translatedLabel="test label" @ellipsis={{true}} />
      </template>
    );

    assert.dom(".d-button-label").hasText("test label…");
  });
});
