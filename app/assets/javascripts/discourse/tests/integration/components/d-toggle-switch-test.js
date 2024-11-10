import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n from "discourse-i18n";

module("Integration | Component | d-toggle-switch", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders a toggle button in a disabled state", async function (assert) {
    this.set("state", false);

    await render(hbs`<DToggleSwitch @state={{this.state}}/>`);

    assert.dom(".d-toggle-switch").exists("renders a toggle switch");
    assert.dom(".d-toggle-switch__checkbox").hasAria("checked", "false");
  });

  test("it renders a toggle button in a enabled state", async function (assert) {
    this.set("state", true);

    await render(hbs`<DToggleSwitch @state={{this.state}}/>`);

    assert.dom(".d-toggle-switch").exists("renders a toggle switch");
    assert.dom(".d-toggle-switch__checkbox").hasAria("checked", "true");
  });

  test("it renders a checkmark icon when enabled", async function (assert) {
    this.set("state", true);

    await render(hbs`<DToggleSwitch @state={{this.state}}/>`);
    assert.dom(".d-toggle-switch__checkbox-slider .d-icon-check").exists();
  });

  test("it renders a label for the button", async function (assert) {
    I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };
    this.set("state", true);
    await render(
      hbs`<DToggleSwitch @state={{this.state}}/ @label={{this.label}} @translatedLabel={{this.translatedLabel}} />`
    );

    this.set("label", "test.fooLabel");

    assert
      .dom(".d-toggle-switch__checkbox-label")
      .hasText(I18n.t("test.fooLabel"));

    this.setProperties({
      label: null,
      translatedLabel: "bar",
    });

    assert.dom(".d-toggle-switch__checkbox-label").hasText("bar");
  });
});
