import { tracked } from "@glimmer/tracking";
import { click, find, render, rerender } from "@ember/test-helpers";
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
    const isCopied = tracked(false);

    await render(
      <template>
        <input class="test-input" readonly value="hello" />
        <DCopyButton
          @isCopied={{isCopied.value}}
          @selector="input.test-input"
          @translatedLabel="Copy"
          @translatedLabelAfterCopy="Copied!"
        />
      </template>
    );

    assert.dom(".copy-button").hasText("Copy");
    assert.dom(".copy-button").doesNotHaveClass("ok");

    isCopied.value = true;

    await rerender();

    assert.dom(".copy-button").hasText("Copied!");
    assert.dom(".copy-button").hasClass("ok");
    assert
      .dom(".sr-only[aria-live='polite']")
      .hasText("Copied!", "the confirmation is announced");
  });

  test("copies the value of an input or the text of an element from @selector", async function (assert) {
    const writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({ writeText }));

    await render(
      <template>
        <input class="test-input" readonly value="from input" />
        <p class="test-text">from text</p>
        <div class="input-button">
          <DCopyButton @selector="input.test-input" @translatedLabel="Copy" />
        </div>
        <div class="text-button">
          <DCopyButton @selector="p.test-text" @translatedLabel="Copy" />
        </div>
      </template>
    );

    await click(".input-button .copy-button");
    await click(".text-button .copy-button");

    assert.deepEqual(
      writeText.args.map(([text]) => text),
      ["from input", "from text"],
      "an input gives its value and an element gives its text"
    );
  });

  test("a copy shows the confirmation and calls @copied", async function (assert) {
    const writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({ writeText }));
    let copied = false;
    const onCopied = () => (copied = true);

    await render(
      <template>
        <DCopyButton
          @copied={{onCopied}}
          @translatedLabel="Copy"
          @translatedLabelAfterCopy="Copied!"
          @value="payload"
        />
      </template>
    );
    // Tests restore the button after 10ms, before `click` settles, so the
    // confirmation is recorded as it renders.
    const button = find(".copy-button");
    const states = new Set();
    const observer = new MutationObserver(() =>
      states.add(
        [
          button.textContent.trim(),
          button.classList.contains("btn-primary"),
          button.classList.contains("ok"),
          Boolean(button.querySelector(".d-icon-check")),
        ].join()
      )
    );
    observer.observe(button, {
      attributes: true,
      characterData: true,
      childList: true,
      subtree: true,
    });

    await click(".copy-button");
    observer.disconnect();

    assert.true(copied, "@copied is called");
    assert.true(
      states.has("Copied!,true,true,true"),
      "the button shows the confirmation with a check"
    );
    assert
      .dom(".copy-button")
      .hasText("Copy", "the button is restored afterwards")
      .doesNotHaveClass("ok");
  });

  test("@icon and @copyClass style the button", async function (assert) {
    await render(
      <template>
        <DCopyButton
          @copyClass="btn-default"
          @icon="clipboard"
          @translatedLabel="Copy"
          @value="payload"
        />
      </template>
    );

    assert
      .dom(".copy-button")
      .hasClass("btn-default")
      .doesNotHaveClass("btn-primary");
    assert.dom(".copy-button .d-icon-clipboard").exists();
  });
});
