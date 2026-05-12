import { click, find, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DButton from "discourse/ui-kit/d-button";
import I18n, { i18n } from "discourse-i18n";

module("Integration | ui-kit | DButton", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a button with default classes when given no args", async function (assert) {
    await render(<template><DButton /></template>);

    assert.dom("button.btn").exists();
    assert.dom("button").hasAttribute("type", "button");
  });

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

  test("form attribute", async function (assert) {
    await render(<template><DButton @form="login-form" /></template>);

    assert.dom("button[form=login-form]").exists("has the form attribute");
  });

  test("link-styled button", async function (assert) {
    await render(<template><DButton @display="link" /></template>);
    assert.dom("button.btn-link:not(.btn)").exists("has the right classes");
  });

  test("isLoading button", async function (assert) {
    this.set("isLoading", true);

    await render(
      <template><DButton @isLoading={{this.isLoading}} /></template>
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
    this.set("disabled", true);

    await render(<template><DButton @disabled={{this.disabled}} /></template>);

    assert.dom("button").isDisabled();

    this.set("disabled", false);
    assert.dom("button").isEnabled();
  });

  test("aria-label", async function (assert) {
    I18n.translations[I18n.locale].js.test = { fooAriaLabel: "foo" };

    await render(
      <template>
        <DButton
          @ariaLabel={{this.ariaLabel}}
          @translatedAriaLabel={{this.translatedAriaLabel}}
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
    I18n.translations[I18n.locale].js.test = { fooTitle: "foo" };

    await render(
      <template>
        <DButton
          @title={{this.title}}
          @translatedTitle={{this.translatedTitle}}
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
    I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };

    await render(
      <template>
        <DButton
          @label={{this.label}}
          @translatedLabel={{this.translatedLabel}}
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
    await render(
      <template><DButton @ariaExpanded={{this.ariaExpanded}} /></template>
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
    await render(
      <template><DButton @ariaControls={{this.ariaControls}} /></template>
    );

    this.set("ariaControls", "foo-bar");
    assert.dom("button").hasAria("controls", "foo-bar");
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
      <template>
        <DButton @action={{this.action}} @onKeyDown={{this.onKeyDown}} />
      </template>
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

    await render(<template><DButton @action={{this.action}} /></template>);

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

    await render(<template><DButton @action={{this.action}} /></template>);

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

  test("suffix icon", async function (assert) {
    await render(
      <template>
        <DButton @translatedLabel="Open menu" @suffixIcon="angle-right" />
      </template>
    );

    assert
      .dom("button .d-button__suffix-icon")
      .exists("has the suffix icon wrapper");
    assert
      .dom("button .d-button__suffix-icon .d-icon-angle-right")
      .exists("has the suffix icon");
  });

  test("@href renders an anchor instead of a button", async function (assert) {
    await render(
      <template>
        <DButton @href="https://example.com" @translatedLabel="Open" />
      </template>
    );

    assert.dom("a.btn").exists();
    assert.dom("a").hasAttribute("href", "https://example.com");
    assert.dom("button").doesNotExist();
  });

  test("@actionParam is passed to the action", async function (assert) {
    this.set("received", null);
    this.set("action", (param) => {
      this.set("received", param);
    });

    await render(
      <template>
        <DButton @action={{this.action}} @actionParam="hello" />
      </template>
    );

    await click(".btn");
    assert.strictEqual(this.received, "hello");
  });

  test("@forwardEvent passes the event as a second argument", async function (assert) {
    this.set("event", null);
    this.set("action", (_param, event) => {
      this.set("event", event);
    });

    await render(
      <template>
        <DButton
          @action={{this.action}}
          @actionParam="x"
          @forwardEvent={{true}}
        />
      </template>
    );

    await click(".btn");
    assert.true(this.event instanceof Event, "the original event is forwarded");
  });

  test("@preventFocus prevents focus on mousedown", async function (assert) {
    await render(<template><DButton @preventFocus={{true}} /></template>);

    const button = find("button");
    let prevented = false;
    button.addEventListener("mousedown", (e) => {
      prevented = e.defaultPrevented;
    });
    button.dispatchEvent(new MouseEvent("mousedown", { cancelable: true }));

    assert.true(prevented, "mousedown default is prevented");
  });

  test("aria-pressed", async function (assert) {
    await render(
      <template><DButton @ariaPressed={{this.ariaPressed}} /></template>
    );

    assert.dom("button").doesNotHaveAria("pressed");

    this.set("ariaPressed", true);
    assert.dom("button").hasAria("pressed", "true");

    this.set("ariaPressed", false);
    assert.dom("button").hasAria("pressed", "false");
  });

  test("@ariaHidden wraps the icon in an aria-hidden span", async function (assert) {
    await render(
      <template><DButton @icon="plus" @ariaHidden={{true}} /></template>
    );

    assert
      .dom('button > span[aria-hidden="true"] .d-icon-plus')
      .exists("the icon is wrapped in an aria-hidden span");
  });

  test("@type accepts submit and reset", async function (assert) {
    await render(<template><DButton @type="submit" /></template>);
    assert.dom("button").hasAttribute("type", "submit");
  });

  test("@id flows through to the button", async function (assert) {
    await render(
      <template><DButton @id="save-button" @translatedLabel="Save" /></template>
    );
    assert.dom("button#save-button").exists();
  });

  test("classes passed via attributes are joined onto the button", async function (assert) {
    await render(
      <template>
        <DButton class="my-button extra" @translatedLabel="x" />
      </template>
    );
    assert.dom("button.btn.my-button.extra").exists();
  });

  test("yielded block content renders alongside the label", async function (assert) {
    await render(
      <template>
        <DButton @translatedLabel="Hello">
          <span class="extra-yield">more</span>
        </DButton>
      </template>
    );

    assert.dom("button .d-button-label").hasText("Hello");
    assert.dom("button .extra-yield").hasText("more");
  });

  test("yielded block content stands in for the label when no @label is given", async function (assert) {
    await render(
      <template>
        <DButton>
          <span class="custom-content">just yield</span>
        </DButton>
      </template>
    );

    assert.dom("button .d-button-label").doesNotExist();
    assert.dom("button .custom-content").hasText("just yield");
  });
});
