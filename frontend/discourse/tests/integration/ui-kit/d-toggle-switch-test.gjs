import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import I18n, { i18n } from "discourse-i18n";

module("Integration | ui-kit | DToggleSwitch", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders a toggle button in a disabled state", async function (assert) {
    await render(<template><DToggleSwitch @state={{false}} /></template>);

    assert.dom(".d-toggle-switch").exists("renders a toggle switch");
    assert.dom(".d-toggle-switch__checkbox").hasAria("checked", "false");
  });

  test("it renders a toggle button in a enabled state", async function (assert) {
    await render(<template><DToggleSwitch @state={{true}} /></template>);

    assert.dom(".d-toggle-switch").exists("renders a toggle switch");
    assert.dom(".d-toggle-switch__checkbox").hasAria("checked", "true");
  });

  test("it renders a checkmark icon when enabled", async function (assert) {
    await render(<template><DToggleSwitch @state={{true}} /></template>);
    assert.dom(".d-toggle-switch__checkbox-slider .d-icon-check").exists();
  });

  test("it renders a label for the button", async function (assert) {
    I18n.translations[I18n.locale].js.test = { fooLabel: "foo" };
    this.set("state", true);
    await render(
      <template>
        <DToggleSwitch
          @label={{this.label}}
          @state={{this.state}}
          @translatedLabel={{this.translatedLabel}}
        />
      </template>
    );

    this.set("label", "test.fooLabel");

    assert
      .dom(".d-toggle-switch__checkbox-label")
      .hasText(i18n("test.fooLabel"));

    this.setProperties({
      label: null,
      translatedLabel: "bar",
    });

    assert.dom(".d-toggle-switch__checkbox-label").hasText("bar");
  });

  test("it names the switch with its label", async function (assert) {
    await render(
      <template>
        <DToggleSwitch @state={{false}} @translatedLabel="bar" />
      </template>
    );

    assert
      .dom(".d-toggle-switch__checkbox")
      .hasAria(
        "labelledby",
        find(".d-toggle-switch__checkbox-label").id,
        "the switch is announced with its visible label"
      );
  });

  test("it leaves an unlabelled switch to its caller", async function (assert) {
    await render(<template><DToggleSwitch @state={{false}} /></template>);

    assert
      .dom(".d-toggle-switch__checkbox")
      .doesNotHaveAttribute("aria-labelledby");
  });
});
