import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DCopyButton from "discourse/ui-kit/d-copy-button";

module("Integration | Component | DCopyButton", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a polite aria-live region so copy success can be announced", async function (assert) {
    await render(
      <template>
        <input class="test-input" value="hello" readonly />
        <DCopyButton
          @selector="input.test-input"
          @translatedLabel="Copy"
          @translatedLabelAfterCopy="Copied!"
        />
      </template>
    );

    assert
      .dom(".sr-only[aria-live='polite']")
      .exists(
        "a visually-hidden polite live region is rendered so screen readers can announce copy success"
      );
  });
});
