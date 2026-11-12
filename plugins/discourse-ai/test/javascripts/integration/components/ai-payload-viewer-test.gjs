import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiPayloadViewer from "discourse/plugins/discourse-ai/discourse/components/ai-payload-viewer";

module("Integration | Component | AiPayloadViewer", function (hooks) {
  setupRenderingTest(hooks);

  test("formats JSON as escaped text", async function (assert) {
    const payload = JSON.stringify({ html: "<img src=x onerror=alert(1)>" });
    const writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({ writeText }));

    await render(
      <template>
        <AiPayloadViewer
          @copyLabel="Copy payload"
          @emptyMessage="Payload not available"
          @payload={{payload}}
        />
      </template>
    );

    assert
      .dom(".ai-payload-viewer__content")
      .hasText(
        '{\n  "html": "<img src=x onerror=alert(1)>"\n}',
        "JSON is formatted as text"
      );
    assert
      .dom(".ai-payload-viewer__content")
      .hasAttribute("tabindex", "0", "long payloads are keyboard-scrollable");
    assert
      .dom(".ai-payload-viewer__copy")
      .hasText("Copy payload", "the copy action is shown by default");
    assert
      .dom(".ai-payload-viewer input[type='hidden']")
      .doesNotExist("copying does not duplicate the payload in the DOM");
    assert
      .dom(".ai-payload-viewer .sr-only[aria-live='polite']")
      .exists("copy confirmation can be announced");
    assert
      .dom(".ai-payload-viewer img")
      .doesNotExist("payload HTML is not rendered");

    await click(".ai-payload-viewer__copy");

    assert.true(
      writeText.calledWithExactly(payload),
      "the original payload is copied directly"
    );
  });

  test("omits the copy action without a label", async function (assert) {
    await render(
      <template>
        <AiPayloadViewer
          @emptyMessage="Payload not available"
          @payload="payload"
          @unbounded={{true}}
        />
      </template>
    );

    assert
      .dom(".ai-payload-viewer__copy")
      .doesNotExist("the copy action can be rendered elsewhere");
    assert
      .dom(".ai-payload-viewer input[type='hidden']")
      .doesNotExist("no unused copy source is rendered");
    assert
      .dom(".ai-payload-viewer")
      .hasClass("--unbounded", "the unbounded layout is exposed as a modifier");
    assert
      .dom(".ai-payload-viewer__content")
      .doesNotHaveAttribute(
        "tabindex",
        "unbounded payloads are not unnecessary tab stops"
      );
  });

  test("shows the unavailable and truncated states", async function (assert) {
    await render(
      <template>
        <AiPayloadViewer
          @copyLabel="Copy payload"
          @emptyMessage="Payload not available"
          @payload=""
        />
      </template>
    );
    assert
      .dom(".ai-payload-viewer__empty")
      .hasText("Payload not available", "missing payloads are explained");

    await render(
      <template>
        <AiPayloadViewer
          @copyLabel="Copy payload"
          @emptyMessage="Payload not available"
          @payload={{null}}
        />
      </template>
    );
    assert
      .dom(".ai-payload-viewer__empty")
      .hasText("Payload not available", "null payloads are explained");

    await render(
      <template>
        <AiPayloadViewer
          @copyLabel="Copy payload"
          @emptyMessage="Payload not available"
          @payload="partial"
          @truncated={{true}}
          @truncatedMessage="Payload truncated"
        />
      </template>
    );
    assert
      .dom(".ai-payload-viewer__notice")
      .hasText("Payload truncated", "truncation is disclosed");
  });
});
