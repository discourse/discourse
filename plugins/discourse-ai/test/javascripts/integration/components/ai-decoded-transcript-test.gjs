import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiDecodedTranscript from "discourse/plugins/discourse-ai/discourse/components/ai-decoded-transcript";

module("Integration | Component | AiDecodedTranscript", function (hooks) {
  setupRenderingTest(hooks);

  test("renders thinking, tool activity, and the response", async function (assert) {
    const transcript = {
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
    };

    await render(
      <template><AiDecodedTranscript @response={{transcript}} /></template>
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

  test("renders answer-only decoded responses without inferring transcript fields", async function (assert) {
    const response = { response: '{"thinking":"about this"}' };

    await render(
      <template><AiDecodedTranscript @response={{response}} /></template>
    );

    assert
      .dom(".ai-decoded-transcript__thinking")
      .doesNotExist("model-authored JSON is not presented as thinking");
    assert
      .dom(".ai-decoded-transcript__section.--response")
      .includesText(
        '{"thinking":"about this"}',
        "the model response remains intact"
      );
  });

  test("ignores invalid and empty decoded responses", async function (assert) {
    for (const response of [
      null,
      "response",
      [],
      {},
      { tool_calls: [null, {}], tool_results: [null, {}] },
    ]) {
      await render(
        <template><AiDecodedTranscript @response={{response}} /></template>
      );
      assert
        .dom(".ai-decoded-transcript")
        .doesNotExist("invalid decoded responses render nothing");
    }
  });

  test("tolerates missing and unexpected tool data", async function (assert) {
    const transcript = {
      thinking: "Still checking",
      tool_calls: [null, { name: "calculator", arguments: false }],
      tool_results: "not an array",
    };

    await render(
      <template><AiDecodedTranscript @response={{transcript}} /></template>
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
