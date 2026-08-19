import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiDecodedTranscript from "discourse/plugins/discourse-ai/discourse/components/ai-decoded-transcript";

module("Integration | Component | AiDecodedTranscript", function (hooks) {
  setupRenderingTest(hooks);

  test("renders thinking, tool activity, and the response", async function (assert) {
    const payload = JSON.stringify({
      thinking: "Check <img src=x onerror=alert(1)>",
      tool_calls: [
        {
          id: "call-1",
          name: "search",
          arguments: { query: "decoder" },
        },
      ],
      tool_results: [
        {
          call_id: "call-1",
          type: "search_result",
          result: { matches: ["Found it"] },
          is_error: true,
        },
      ],
      response: "Done",
    });

    await render(
      <template><AiDecodedTranscript @payload={{payload}} /></template>
    );

    assert
      .dom(".ai-decoded-transcript__thinking[open]")
      .exists("thinking is visible by default");
    assert
      .dom(".ai-decoded-transcript__thinking")
      .includesText(
        "Check <img src=x onerror=alert(1)>",
        "thinking is rendered as text"
      );
    assert
      .dom(".ai-decoded-transcript img")
      .doesNotExist("model-generated HTML is escaped");
    assert
      .dom(".ai-decoded-transcript__item")
      .exists({ count: 2 }, "the tool call and result are listed");
    assert
      .dom(".ai-decoded-transcript__item-heading")
      .includesText("search", "the tool name is visible");
    assert
      .dom(".ai-decoded-transcript__code")
      .includesText('"query": "decoder"', "arguments are formatted");
    assert
      .dom(".ai-decoded-transcript__item.--error")
      .includesText('"matches": [', "structured error results are formatted");
    assert
      .dom(".ai-decoded-transcript__list[role='list']")
      .exists({ count: 2 }, "tool collections retain list semantics");
    assert
      .dom(".ai-decoded-transcript__code[dir='ltr']")
      .exists({ count: 2 }, "structured payloads use isolated text direction");
    assert
      .dom(".ai-decoded-transcript__code[tabindex]")
      .doesNotExist("non-scrollable code blocks are not tab stops");
    assert
      .dom(".ai-decoded-transcript__section.--response")
      .includesText("Done", "the final response is visible");
  });

  test("renders plain and unrecognized JSON responses as text", async function (assert) {
    const ambiguousPayload = JSON.stringify({
      response: "Done",
      metadata: { source: "api" },
    });
    const emptyPayload = JSON.stringify({ response: null });

    await render(
      <template><AiDecodedTranscript @payload="Plain response" /></template>
    );

    assert
      .dom(".ai-decoded-transcript__text")
      .hasText("Plain response", "plain decoded responses are rendered");
    assert
      .dom(".ai-decoded-transcript__thinking")
      .doesNotExist("plain responses have no thinking section");

    await render(
      <template>
        <AiDecodedTranscript @payload='{"answer":"JSON response"}' />
      </template>
    );

    assert
      .dom(".ai-decoded-transcript__text")
      .hasText(
        '{"answer":"JSON response"}',
        "unrecognized JSON remains intact"
      );
    await render(
      <template><AiDecodedTranscript @payload={{ambiguousPayload}} /></template>
    );

    assert
      .dom(".ai-decoded-transcript__text")
      .hasText(
        ambiguousPayload,
        "ambiguous JSON is preserved without losing fields"
      );

    await render(
      <template><AiDecodedTranscript @payload={{emptyPayload}} /></template>
    );

    assert
      .dom(".ai-decoded-transcript__text")
      .hasText(emptyPayload, "empty transcript-shaped JSON remains visible");
  });

  test("tolerates missing and unexpected tool data", async function (assert) {
    const payload = JSON.stringify({
      thinking: "Still checking",
      tool_calls: [null, { name: "calculator", arguments: false }],
      tool_results: "not an array",
    });

    await render(
      <template><AiDecodedTranscript @payload={{payload}} /></template>
    );

    assert
      .dom(".ai-decoded-transcript__item")
      .exists({ count: 1 }, "invalid calls are omitted from the transcript");
    assert
      .dom(".ai-decoded-transcript__code")
      .hasText("false", "non-object arguments remain readable");
    assert
      .dom(".ai-decoded-transcript__section")
      .exists({ count: 1 }, "invalid result collections are omitted");
  });
});
