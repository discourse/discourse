import { click, find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import decorateAiThinking from "discourse/plugins/discourse-ai/discourse/lib/decorate-ai-thinking";

module("Integration | Component | AiThinking", function (hooks) {
  setupRenderingTest(hooks);

  test("decorates thinking with accessible SVG carets without duplicating them", async function (assert) {
    await render(
      <template>
        <div class="thinking-test">
          <details class="ai-thinking">
            <summary>Thinking</summary>
            <p>Considering the request.</p>
          </details>
          <details class="other-details"><summary>Other details</summary></details>
        </div>
      </template>
    );

    decorateAiThinking(find(".thinking-test"));
    decorateAiThinking(find(".thinking-test"));

    assert
      .dom(".ai-thinking summary")
      .hasText("Thinking", "preserves the summary's accessible name");
    assert
      .dom(".ai-thinking .ai-details__caret")
      .exists(
        { count: 2 },
        "adds one pair of icons across repeated decorations"
      );
    assert
      .dom(".ai-thinking .d-icon-chevron-right")
      .hasAttribute(
        "aria-hidden",
        "true",
        "the decorative icon is hidden from assistive technology"
      )
      .isVisible("shows the collapsed caret");
    assert
      .dom(".ai-thinking .d-icon-chevron-down")
      .isNotVisible("hides the expanded caret while closed");
    assert
      .dom(".other-details .ai-details__caret")
      .doesNotExist("leaves unrelated disclosures alone");

    await click(".ai-thinking summary");

    assert.strictEqual(
      getComputedStyle(find(".ai-thinking summary"), "::before").content,
      "none",
      "the open state does not restore the text triangle"
    );
    assert
      .dom(".ai-thinking .d-icon-chevron-right")
      .isNotVisible("hides the collapsed caret when open");
    assert
      .dom(".ai-thinking .d-icon-chevron-down")
      .isVisible("shows the expanded caret");
  });
});
