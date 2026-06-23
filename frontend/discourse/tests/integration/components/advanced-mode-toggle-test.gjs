import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdvancedModeToggle from "discourse/components/advanced-mode-toggle";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | AdvancedModeToggle", function (hooks) {
  setupRenderingTest(hooks);

  test("label reflects @active and flips on toggle", async function (assert) {
    let active = false;
    const onToggle = () => (active = !active);

    await render(
      <template>
        <AdvancedModeToggle @active={{active}} @onToggle={{onToggle}} />
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
});
