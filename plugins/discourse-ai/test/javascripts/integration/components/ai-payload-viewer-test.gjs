import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiPayloadViewer from "discourse/plugins/discourse-ai/discourse/components/ai-payload-viewer";

module("Integration | Component | AiPayloadViewer", function (hooks) {
  setupRenderingTest(hooks);

  test("formats JSON as escaped text", async function (assert) {
    const payload = JSON.stringify({ html: "<img src=x onerror=alert(1)>" });

    await render(
      <template>
        <AiPayloadViewer
          @payload={{payload}}
          @copyLabel="Copy payload"
          @emptyMessage="Payload not available"
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
      .dom(".ai-payload-viewer img")
      .doesNotExist("payload HTML is not rendered");
  });

  test("shows the unavailable and truncated states", async function (assert) {
    await render(
      <template>
        <AiPayloadViewer
          @payload=""
          @copyLabel="Copy payload"
          @emptyMessage="Payload not available"
        />
      </template>
    );
    assert
      .dom(".ai-payload-viewer__empty")
      .hasText("Payload not available", "missing payloads are explained");

    await render(
      <template>
        <AiPayloadViewer
          @payload={{null}}
          @copyLabel="Copy payload"
          @emptyMessage="Payload not available"
        />
      </template>
    );
    assert
      .dom(".ai-payload-viewer__empty")
      .hasText("Payload not available", "null payloads are explained");

    await render(
      <template>
        <AiPayloadViewer
          @payload="partial"
          @truncated={{true}}
          @copyLabel="Copy payload"
          @emptyMessage="Payload not available"
          @truncatedMessage="Payload truncated"
        />
      </template>
    );
    assert
      .dom(".ai-payload-viewer__notice")
      .hasText("Payload truncated", "truncation is disclosed");
  });
});
