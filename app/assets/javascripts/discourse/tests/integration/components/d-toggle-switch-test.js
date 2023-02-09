import { module, test } from "qunit";
import { render } from "@ember/test-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { hbs } from "ember-cli-htmlbars";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";

module("Integration | Component | d-toggle-switch", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders a toggle button in a disabled state", async function (assert) {
    this.set("state", false);

    await render(hbs`<DToggleSwitch @state={{this.state}}/>`);

    assert.ok(exists(".d-toggle-switch"), "it renders a toggle switch");
    assert.strictEqual(
      query(".d-toggle-switch__checkbox").ariaChecked,
      "false"
    );
  });

  test("it renders a toggle button in a enabled state", async function (assert) {
    this.set("state", true);

    await render(hbs`<DToggleSwitch @state={{this.state}}/>`);

    assert.ok(exists(".d-toggle-switch"), "it renders a toggle switch");
    assert.strictEqual(query(".d-toggle-switch__checkbox").ariaChecked, "true");
  });

  test("it renders a checkmark icon when enabled", async function (assert) {
    this.set("state", true);

    await render(hbs`<DToggleSwitch @state={{this.state}}/>`);
    assert.ok(exists(".d-toggle-switch__checkbox-slider .d-icon-check"));
  });

  test("it renders a label for the button", async function (assert) {
    I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };
    this.set("state", true);
    await render(
      hbs`<DToggleSwitch @state={{this.state}}/ @label={{this.label}} @translatedLabel={{this.translatedLabel}} />`
    );

    this.set("label", "test.fooLabel");

    assert.strictEqual(
      query(".d-toggle-switch__checkbox-label").innerText,
      I18n.t("test.fooLabel")
    );

    this.setProperties({
      label: null,
      translatedLabel: "bar",
    });

    assert.strictEqual(
      query(".d-toggle-switch__checkbox-label").innerText,
      "bar"
    );
  });
});
