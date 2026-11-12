import { later } from "@ember/runloop";
import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SmoothStreamer from "discourse/plugins/discourse-ai/discourse/lib/smooth-streamer";

module("Unit | Lib | smooth-streamer", function (hooks) {
  setupTest(hooks);

  test("it initializes correctly", function (assert) {
    let mockText = "";
    const getRealtimeText = () => mockText;
    const setRealtimeText = (val) => (mockText = val);

    const streamer = new SmoothStreamer(getRealtimeText, setRealtimeText);

    assert.false(streamer.isStreaming, "isStreaming should be false initially");
    assert.strictEqual(
      streamer.renderedText,
      "",
      "renderedText should be empty initially"
    );
  });

  test("it streams text with animation", async function (assert) {
    let mockText = "";
    const getRealtimeText = () => mockText;
    const setRealtimeText = (val) => (mockText = val);

    const streamer = new SmoothStreamer(getRealtimeText, setRealtimeText);
    const result1 = { text: "Hello", done: false };

    await streamer.updateResult(result1, "text");
    assert.true(
      streamer.isStreaming,
      "isStreaming should be true while animating"
    );

    await settled();
    assert.strictEqual(
      streamer.realtimeText,
      "Hello",
      "Realtime text should be updated immediately"
    );
    assert.true(
      streamer.streamedText.length > 0,
      "Streamed text should start appearing"
    );

    await new Promise((resolve) => later(resolve, 50));
    assert.strictEqual(
      streamer.streamedText,
      "Hello",
      "Streamed text should fully appear"
    );
  });

  test("it stops streaming when done", async function (assert) {
    let mockText = "";
    const getRealtimeText = () => mockText;
    const setRealtimeText = (val) => (mockText = val);

    const streamer = new SmoothStreamer(getRealtimeText, setRealtimeText);
    await streamer.updateResult({ text: "Done text", done: true }, "text");

    assert.false(streamer.isStreaming, "isStreaming should be false when done");
    assert.strictEqual(
      streamer.streamedText,
      "Done text",
      "Streamed text should be complete"
    );
    assert.strictEqual(
      streamer.realtimeText,
      "Done text",
      "Realtime text should match the final input"
    );
  });

  test("it can finish a stream without jumping to the final text", async function (assert) {
    let mockText = "";
    const getRealtimeText = () => mockText;
    const setRealtimeText = (val) => (mockText = val);
    const streamer = new SmoothStreamer(getRealtimeText, setRealtimeText, 1, {
      smoothCompletion: true,
    });
    const finalText =
      "A complete answer that arrived before the animation caught up.";

    await streamer.updateResult({ text: "A comp", done: false }, "text");
    await streamer.updateResult({ text: finalText, done: true }, "text");

    assert.true(
      streamer.isStreaming,
      "the final update keeps animating briefly"
    );
    assert.notStrictEqual(
      streamer.renderedText,
      finalText,
      "the remaining answer is not revealed in one jump"
    );

    await settled();

    assert.false(streamer.isStreaming, "animation ends after catching up");
    assert.strictEqual(streamer.renderedText, finalText);
  });

  test("resetStreaming clears all progress", function (assert) {
    let mockText = "Some text";
    const getRealtimeText = () => mockText;
    const setRealtimeText = (val) => (mockText = val);

    const streamer = new SmoothStreamer(getRealtimeText, setRealtimeText);
    streamer.streamedText = "Some text";
    streamer.streamedTextLength = 9;
    streamer.isStreaming = true;

    streamer.resetStreaming();

    assert.strictEqual(
      streamer.streamedText,
      "",
      "Streamed text should be cleared"
    );
    assert.strictEqual(
      streamer.streamedTextLength,
      0,
      "Streamed text length should be reset"
    );
    assert.false(
      streamer.isStreaming,
      "isStreaming should be false after reset"
    );
  });
});
