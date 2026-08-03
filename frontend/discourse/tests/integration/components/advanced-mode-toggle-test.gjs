import { tracked } from "@glimmer/tracking";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdvancedModeToggle from "discourse/components/advanced-mode-toggle";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | AdvancedModeToggle", function (hooks) {
  setupRenderingTest(hooks);

  test("label reflects @active and flips on toggle", async function (assert) {
    const state = new (class {
      @tracked active = false;
    })();
    const onToggle = () => (state.active = !state.active);

    await render(
      <template>
        <AdvancedModeToggle @active={{state.active}} @onToggle={{onToggle}} />
      </template>
    );

    assert
      .dom(".advanced-mode-btn")
      .hasText(
        i18n("advanced_mode_toggle.advanced_mode"),
        "shows 'Advanced mode' when inactive"
      );

    await click(".advanced-mode-btn");

    assert
      .dom(".advanced-mode-btn")
      .hasText(
        i18n("advanced_mode_toggle.simple_mode"),
        "shows 'Simple mode' once active"
      );
  });

  test("keeps an accessible name for when the label is hidden", async function (assert) {
    const noop = () => {};

    await render(
      <template>
        <AdvancedModeToggle @active={{false}} @onToggle={{noop}} />
      </template>
    );

    assert
      .dom(".advanced-mode-btn")
      .hasAria(
        "label",
        i18n("advanced_mode_toggle.advanced_mode"),
        "below the sm breakpoint the label is hidden, so the name has to come from aria-label"
      );
  });
});
