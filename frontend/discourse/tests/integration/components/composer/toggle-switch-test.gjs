import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ToggleSwitch from "discourse/components/composer/toggle-switch";
import { formatShortcut } from "discourse/lib/shortcut-format";
import { capabilities } from "discourse/services/capabilities";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | composer/toggle-switch", function (hooks) {
  setupRenderingTest(hooks);

  test("gate: names the shortcut in its label only with a keyboard", async function (assert) {
    const shortcut = formatShortcut("ctrl+m");

    await render(<template><ToggleSwitch @state={{true}} /></template>);

    assert
      .dom(".composer-toggle-switch")
      .hasAttribute(
        "aria-label",
        i18n("composer.switch_to_markdown", {
          keyboardShortcut: shortcut.label,
        })
      )
      .hasAttribute("aria-keyshortcuts", shortcut.aria);

    sinon.stub(capabilities, "hasKeyboard").get(() => false);
    await render(<template><ToggleSwitch @state={{true}} /></template>);

    assert
      .dom(".composer-toggle-switch")
      .hasAttribute(
        "aria-label",
        i18n("composer.switch_to_markdown_no_shortcut")
      )
      .doesNotHaveAttribute("aria-keyshortcuts");
  });
});
