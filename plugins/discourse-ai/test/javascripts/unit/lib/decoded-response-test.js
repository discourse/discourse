import { module, test } from "qunit";
import {
  decodedResponseText,
  isDecodedResponse,
} from "discourse/plugins/discourse-ai/discourse/lib/decoded-response";

module("Unit | Lib | decoded-response", function () {
  test("identifies normalized decoded responses", function (assert) {
    assert.true(
      isDecodedResponse({ response: "answer" }),
      "answer-only responses are valid"
    );
    assert.true(
      isDecodedResponse({
        tool_calls: [{ name: "search", arguments: { query: "docs" } }],
      }),
      "valid tool-only responses are valid"
    );
    assert.true(
      isDecodedResponse({ tool_results: [{ result: "Found it" }] }),
      "valid result-only responses are valid"
    );
    assert.false(
      isDecodedResponse({ tool_calls: [null, {}] }),
      "invalid tool calls do not create a decoded response"
    );
    assert.false(
      isDecodedResponse({ tool_results: [null, {}] }),
      "invalid tool results do not create a decoded response"
    );
    assert.false(
      isDecodedResponse({ response: { thinking: "spoofed" } }),
      "non-string responses are invalid"
    );
    assert.false(isDecodedResponse({}), "empty objects are invalid");
    assert.false(isDecodedResponse(null), "null is invalid");
    assert.false(isDecodedResponse("answer"), "strings are invalid");
    assert.false(isDecodedResponse([]), "arrays are invalid");
  });

  test("preserves plain answer copy and formats transcripts", function (assert) {
    assert.strictEqual(
      decodedResponseText({ response: "answer" }),
      "answer",
      "answer-only responses copy as plain text"
    );
    assert.strictEqual(
      decodedResponseText({ thinking: "reason", response: "answer" }),
      '{\n  "thinking": "reason",\n  "response": "answer"\n}',
      "multi-section responses copy as readable JSON"
    );
    assert.strictEqual(
      decodedResponseText(null),
      null,
      "invalid responses have no copy value"
    );
  });
});
