import { module, test } from "qunit";
import DiffStreamer from "discourse/plugins/discourse-ai/discourse/lib/diff-streamer";

module("Unit | Lib | diff-streamer", function () {
  test("streamingDiff correctly handles trivial cases", async function (assert) {
    const originalText = "helo world";
    const targetText = "hello world";

    const diffStreamer = new DiffStreamer(this.originalTextContent);
    await diffStreamer.loadJSDiff();

    const diffResult = diffStreamer.streamingDiff(originalText, targetText);

    const expectedDiff = [
      { count: 1, added: false, removed: true, value: "helo" },
      { count: 1, added: true, removed: false, value: "hello" },
      { count: 2, added: false, removed: false, value: " world" },
    ];

    assert.deepEqual(
      diffResult,
      expectedDiff,
      "Diff result should match the expected structure"
    );
  });

  test("streamingDiff correctly consolidates and handles diff drift", async function (assert) {
    const originalText =
      "This is todone, but I want to can why.\n\nWe\n\nSEO Tags supports a `canonical_url` override. I tried a few possibilities there. The one I wanted to work, ex: `https://www.discourse.org/de`, appended an extra `/de` on the URL, only in the deploy b";
    const targetText = "This is to-done";

    const diffStreamer = new DiffStreamer(this.originalTextContent);
    await diffStreamer.loadJSDiff();

    const diffResult = diffStreamer.streamingDiff(originalText, targetText);

    // Verify the diff result is an array with the expected structure
    assert.true(Array.isArray(diffResult), "Diff result should be an array");
    assert.strictEqual(
      diffResult.length,
      3,
      "Expecting exactly three parts in the diff result"
    );

    assert.strictEqual(
      diffResult[0].value,
      "This is ",
      "First part should be unchanged"
    );

    assert.strictEqual(
      diffResult[1].value,
      "to-done",
      "Second part should be an insertion"
    );

    assert.true(diffResult[1].added, "Second part should be an insertion");

    assert.strictEqual(
      diffResult[2].value.length,
      235,
      "Third part should include all text"
    );

    assert.true(diffResult[2].removed, "Third part should be a removal");
  });
});
