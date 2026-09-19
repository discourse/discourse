import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Service | ai-bot-streaming-state", function (hooks) {
  setupTest(hooks);

  test("isStreamingForTopic returns false when topic is not started", function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-streaming-state");
    assert.false(service.isStreamingForTopic(42));
    assert.false(service.isStreamingForTopic(null));
    assert.false(service.isStreamingForTopic(undefined));
  });

  test("markStarted + markFinished transitions state", function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-streaming-state");

    service.markStarted(42, 100);
    assert.true(service.isStreamingForTopic(42));
    assert.strictEqual(service.streamingPostIdForTopic(42), 100);

    service.markFinished(42);
    assert.false(service.isStreamingForTopic(42));
    assert.strictEqual(service.streamingPostIdForTopic(42), null);
  });

  test("markStarted with null topicId is a no-op", function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-streaming-state");
    service.markStarted(null, 100);
    assert.false(service.isStreamingForTopic(null));
  });

  test("markFinished for an untracked topic is a no-op", function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-streaming-state");
    // should not throw
    service.markFinished(999);
    assert.false(service.isStreamingForTopic(999));
  });

  test("markStarted without postId does not arm the idle timer", function (assert) {
    // Optimistic mark (no postId) should leave the entry alive indefinitely
    // so slow model start-up doesn't race the idle timer.
    const service = getOwner(this).lookup("service:ai-bot-streaming-state");
    service.markStarted(42, null);
    assert.true(service.isStreamingForTopic(42));
    assert.strictEqual(service.streamingPostIdForTopic(42), null);
  });

  test("stopStreaming without a known postId just clears local state", async function (assert) {
    let requestsCount = 0;
    pretender.post("/discourse-ai/ai-bot/post/:postId/stop-streaming", () => {
      requestsCount += 1;
      return response(200, {});
    });

    const service = getOwner(this).lookup("service:ai-bot-streaming-state");
    service.markStarted(42, null); // optimistic mark, no postId yet

    await service.stopStreaming(42);

    assert.strictEqual(requestsCount, 0, "no network call when postId unknown");
    assert.false(service.isStreamingForTopic(42));
  });

  test("stopStreaming hits /stop-streaming for the known postId and clears state", async function (assert) {
    let stoppedPostId;
    pretender.post(
      "/discourse-ai/ai-bot/post/:postId/stop-streaming",
      (request) => {
        stoppedPostId = request.params.postId;
        return response(200, {});
      }
    );

    const service = getOwner(this).lookup("service:ai-bot-streaming-state");
    service.markStarted(42, 100);

    await service.stopStreaming(42);

    assert.strictEqual(stoppedPostId, "100");
    assert.false(service.isStreamingForTopic(42));
  });

  test("multiple topics can stream concurrently without interference", function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-streaming-state");

    service.markStarted(1, 10);
    service.markStarted(2, 20);

    assert.true(service.isStreamingForTopic(1));
    assert.true(service.isStreamingForTopic(2));
    assert.strictEqual(service.streamingPostIdForTopic(1), 10);
    assert.strictEqual(service.streamingPostIdForTopic(2), 20);

    service.markFinished(1);

    assert.false(service.isStreamingForTopic(1));
    assert.true(service.isStreamingForTopic(2));
  });
});
