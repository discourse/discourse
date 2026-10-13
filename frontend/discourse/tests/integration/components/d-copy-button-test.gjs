import { tracked } from "@glimmer/tracking";
import { click, render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DCopyButton from "discourse/ui-kit/d-copy-button";

module("Integration | Component | DCopyButton", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a polite aria-live region so copy success can be announced", async function (assert) {
    await render(
      <template>
        <input class="test-input" readonly value="hello" />
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

  test("copies a direct value without a DOM source", async function (assert) {
    const writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({ writeText }));

    await render(
      <template>
        <DCopyButton
          @selector=".missing-copy-source"
          @translatedLabel="Copy"
          @translatedLabelAfterCopy="Copied!"
          @value="direct payload"
        />
      </template>
    );

    await click(".copy-button");

    assert.true(
      writeText.calledWithExactly("direct payload"),
      "the direct value takes precedence over the selector"
    );
  });

  test("@isCopied shows the confirmation for a copy made by the caller", async function (assert) {
    const state = new (class {
      @tracked isCopied = false;
    })();

    await render(
      <template>
        <input class="test-input" readonly value="hello" />
        <DCopyButton
          @isCopied={{state.isCopied}}
          @selector="input.test-input"
          @translatedLabel="Copy"
          @translatedLabelAfterCopy="Copied!"
        />
      </template>
    );

    assert.dom(".copy-button").hasText("Copy");
    assert.dom(".copy-button").doesNotHaveClass("ok");

    state.isCopied = true;

    await rerender();

    assert.dom(".copy-button").hasText("Copied!");
    assert.dom(".copy-button").hasClass("ok");
    assert
      .dom(".sr-only[aria-live='polite']")
      .hasText("Copied!", "the confirmation is announced");
  });
});
