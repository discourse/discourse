import ClassicComponent from "@ember/component";
import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { withSilencedDeprecationsAsync } from "discourse-common/lib/deprecated";
import I18n from "discourse-i18n";

module("Integration | Component | d-button", function (hooks) {
  setupRenderingTest(hooks);

  test("icon only button", async function (assert) {
    await render(hbs`<DButton @icon="plus" tabindex="3" />`);

    assert.ok(exists("button.btn.btn-icon.no-text"), "it has all the classes");
    assert.ok(exists("button .d-icon.d-icon-plus"), "it has the icon");
    assert.strictEqual(
      query("button").getAttribute("tabindex"),
      "3",
      "it has the tabindex"
    );
  });

  test("icon and text button", async function (assert) {
    await render(hbs`<DButton @icon="plus" @label="topic.create" />`);

    assert.ok(exists("button.btn.btn-icon-text"), "it has all the classes");
    assert.ok(exists("button .d-icon.d-icon-plus"), "it has the icon");
    assert.ok(exists("button span.d-button-label"), "it has the label");
  });

  test("text only button", async function (assert) {
    await render(hbs`<DButton @label="topic.create" />`);

    assert.ok(exists("button.btn.btn-text"), "it has all the classes");
    assert.ok(exists("button span.d-button-label"), "it has the label");
  });

  test("form attribute", async function (assert) {
    await render(hbs`<DButton @form="login-form" />`);

    assert.ok(exists("button[form=login-form]"), "it has the form attribute");
  });

  test("link-styled button", async function (assert) {
    await render(hbs`<DButton @display="link" />`);

    assert.ok(exists("button.btn-link:not(.btn)"), "it has the right classes");
  });

  test("isLoading button", async function (assert) {
    this.set("isLoading", true);

    await render(hbs`<DButton @isLoading={{this.isLoading}} />`);

    assert.ok(
      exists("button.is-loading .loading-icon"),
      "it has a spinner showing"
    );
    assert.ok(
      exists("button[disabled]"),
      "while loading the button is disabled"
    );

    this.set("isLoading", false);

    assert.notOk(
      exists("button .loading-icon"),
      "it doesn't have a spinner showing"
    );
    assert.ok(
      exists("button:not([disabled])"),
      "while not loading the button is enabled"
    );
  });

  test("button without isLoading attribute", async function (assert) {
    await render(hbs`<DButton />`);

    assert.notOk(
      exists("button.is-loading"),
      "it doesn't have class is-loading"
    );
    assert.notOk(
      exists("button .loading-icon"),
      "it doesn't have a spinner showing"
    );
    assert.notOk(exists("button[disabled]"), "it isn't disabled");
  });

  test("isLoading button explicitly set to undefined state", async function (assert) {
    this.set("isLoading");

    await render(hbs`<DButton @isLoading={{this.isLoading}} />`);

    assert.notOk(
      exists("button.is-loading"),
      "it doesn't have class is-loading"
    );
    assert.notOk(
      exists("button .loading-icon"),
      "it doesn't have a spinner showing"
    );
    assert.notOk(exists("button[disabled]"), "it isn't disabled");
  });

  test("disabled button", async function (assert) {
    this.set("disabled", true);

    await render(hbs`<DButton @disabled={{this.disabled}} />`);

    assert.ok(exists("button[disabled]"), "the button is disabled");

    this.set("disabled", false);
    assert.ok(exists("button:not([disabled])"), "the button is enabled");
  });

  test("aria-label", async function (assert) {
    I18n.translations[I18n.locale].js.test = { fooAriaLabel: "foo" };

    await render(
      hbs`<DButton @ariaLabel={{this.ariaLabel}} @translatedAriaLabel={{this.translatedAriaLabel}} />`
    );

    this.set("ariaLabel", "test.fooAriaLabel");

    assert.strictEqual(
      query("button").getAttribute("aria-label"),
      I18n.t("test.fooAriaLabel")
    );

    this.setProperties({
      ariaLabel: null,
      translatedAriaLabel: "bar",
    });

    assert.dom("button").hasAttribute("aria-label", "bar");
  });

  test("title", async function (assert) {
    I18n.translations[I18n.locale].js.test = { fooTitle: "foo" };

    await render(
      hbs`<DButton @title={{this.title}} @translatedTitle={{this.translatedTitle}} />`
    );

    this.set("title", "test.fooTitle");
    assert.strictEqual(
      query("button").getAttribute("title"),
      I18n.t("test.fooTitle")
    );

    this.setProperties({
      title: null,
      translatedTitle: "bar",
    });

    assert.dom("button").hasAttribute("title", "bar");
  });

  test("label", async function (assert) {
    I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };

    await render(
      hbs`<DButton @label={{this.label}} @translatedLabel={{this.translatedLabel}} />`
    );

    this.set("label", "test.fooLabel");

    assert.dom("button .d-button-label").hasText(I18n.t("test.fooLabel"));

    this.setProperties({
      label: null,
      translatedLabel: "bar",
    });

    assert.dom("button .d-button-label").hasText("bar");
  });

  test("aria-expanded", async function (assert) {
    await render(hbs`<DButton @ariaExpanded={{this.ariaExpanded}} />`);

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
    await render(hbs`<DButton @ariaControls={{this.ariaControls}} />`);

    this.set("ariaControls", "foo-bar");
    assert.strictEqual(
      query("button").getAttribute("aria-controls"),
      "foo-bar"
    );
  });

  test("onKeyDown callback", async function (assert) {
    this.set("foo", null);
    this.set("onKeyDown", () => {
      this.set("foo", "bar");
    });
    this.set("action", () => {
      this.set("foo", "baz");
    });

    await render(
      hbs`<DButton @action={{this.action}} @onKeyDown={{this.onKeyDown}} />`
    );

    await triggerKeyEvent(".btn", "keydown", "Space");
    assert.strictEqual(this.foo, "bar");

    await triggerKeyEvent(".btn", "keydown", "Enter");
    assert.strictEqual(this.foo, "bar");
  });

  test("press Enter", async function (assert) {
    this.set("foo", null);
    this.set("action", () => {
      this.set("foo", "bar");
    });

    await render(hbs`<DButton @action={{this.action}} />`);

    await triggerKeyEvent(".btn", "keydown", "Space");
    assert.strictEqual(this.foo, null);

    await triggerKeyEvent(".btn", "keydown", "Enter");
    assert.strictEqual(this.foo, "bar");
  });

  test("@action function is triggered on click", async function (assert) {
    this.set("foo", null);
    this.set("action", () => {
      this.set("foo", "bar");
    });

    await render(hbs`<DButton @action={{this.action}} />`);

    await click(".btn");

    assert.strictEqual(this.foo, "bar");
  });

  test("@action can sendAction when passed a string", async function (assert) {
    this.set("foo", null);
    this.set("legacyActionTriggered", () => this.set("foo", "bar"));

    this.classicComponent = ClassicComponent.extend({
      actions: {
        myLegacyAction() {
          this.legacyActionTriggered();
        },
      },
      layout: hbs`<DButton @action="myLegacyAction" />`,
    });

    await withSilencedDeprecationsAsync(
      "discourse.d-button-action-string",
      async () => {
        await render(
          hbs`<this.classicComponent @legacyActionTriggered={{this.legacyActionTriggered}} />`
        );

        await click(".btn");
      }
    );

    assert.strictEqual(this.foo, "bar");
  });

  test("Uses correct target with @action string when component called with block", async function (assert) {
    this.set("foo", null);
    this.set("legacyActionTriggered", () => this.set("foo", "bar"));

    this.simpleWrapperComponent = ClassicComponent.extend();

    this.classicComponent = ClassicComponent.extend({
      actions: {
        myLegacyAction() {
          this.legacyActionTriggered();
        },
      },
      layout: hbs`<@simpleWrapperComponent><DButton @action="myLegacyAction" /></@simpleWrapperComponent>`,
    });

    await withSilencedDeprecationsAsync(
      "discourse.d-button-action-string",
      async () => {
        await render(
          hbs`<this.classicComponent @legacyActionTriggered={{this.legacyActionTriggered}} @simpleWrapperComponent={{this.simpleWrapperComponent}} />`
        );

        await click(".btn");
      }
    );

    assert.strictEqual(this.foo, "bar");
  });

  test("ellipses", async function (assert) {
    await render(
      hbs`<DButton @translatedLabel="test label" @ellipsis={{true}} />`
    );

    assert.dom(".d-button-label").hasText("test label…");
  });
});
