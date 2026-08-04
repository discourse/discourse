import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { durationTiny } from "discourse/lib/formatter";
import {
  formatMs,
  messageBytes,
  messagePreview,
  prettyJson,
  relativeShortTime,
  shortSource,
} from "discourse/static/dev-tools/message-bus/format";
import { i18n } from "discourse-i18n";

const NOW = 1_700_000_000_000;

let nextSeq = 1;

/** Builds an observed message around `data`, which is what both helpers take. */
function observed(data) {
  return {
    seq: nextSeq++,
    channel: "/alpha",
    messageId: 1,
    globalId: 1,
    data,
    receivedAt: NOW,
  };
}

module("Unit | Lib | dev-tools | message-bus-format", function (hooks) {
  setupTest(hooks);

  test("a missing timestamp reads as nothing at all", function (assert) {
    assert.strictEqual(relativeShortTime(null, NOW), "");
    assert.strictEqual(
      relativeShortTime(undefined, NOW),
      "",
      "a subscription that has never been called reads the same as one with no timestamp at all"
    );
  });

  test("under a minute reads in whole seconds", function (assert) {
    assert.strictEqual(
      relativeShortTime(NOW, NOW),
      i18n("dates.tiny.x_seconds", { count: 0 }),
      "a message that just arrived reads as zero seconds, not as a duration"
    );
    assert.strictEqual(
      relativeShortTime(NOW - 5_000, NOW),
      i18n("dates.tiny.x_seconds", { count: 5 })
    );
    assert.strictEqual(
      relativeShortTime(NOW - 59_000, NOW),
      i18n("dates.tiny.x_seconds", { count: 59 }),
      "the last second before a minute is still counted in seconds"
    );
  });

  test("sub-second remainders are rounded, not truncated", function (assert) {
    assert.strictEqual(
      relativeShortTime(NOW - 5_400, NOW),
      i18n("dates.tiny.x_seconds", { count: 5 })
    );
    assert.strictEqual(
      relativeShortTime(NOW - 5_600, NOW),
      i18n("dates.tiny.x_seconds", { count: 6 })
    );
  });

  test("a minute or more hands over to the shared duration helper", function (assert) {
    assert.strictEqual(
      relativeShortTime(NOW - 60_000, NOW),
      durationTiny(60),
      "the panel does not invent its own wording for durations"
    );
    assert.strictEqual(
      relativeShortTime(NOW - 3_600_000, NOW),
      durationTiny(3600)
    );
    assert.strictEqual(
      relativeShortTime(NOW - 172_800_000, NOW),
      durationTiny(172_800)
    );
  });

  test("a timestamp in the future never reads as negative", function (assert) {
    assert.strictEqual(
      relativeShortTime(NOW + 5_000, NOW),
      i18n("dates.tiny.x_seconds", { count: 0 }),
      "a clock that is momentarily ahead reads as just now rather than as a negative age"
    );
  });

  test("a duration of 100ms or more reads in whole milliseconds", function (assert) {
    assert.strictEqual(formatMs(142), "142");
    assert.strictEqual(
      formatMs(142.6),
      "143",
      // At this size the tenth of a millisecond is below the noise floor of
      // what the number is being read for.
      "a duration this long is rounded rather than carrying a fraction"
    );
    assert.strictEqual(formatMs(100), "100", "100 is already in that range");
    assert.strictEqual(formatMs(1234.56), "1235");
  });

  test("a shorter duration keeps one decimal, without the noise it was measured with", function (assert) {
    assert.strictEqual(
      formatMs(0.6000000014901161),
      "0.6",
      // performance.now() differences arrive with a long tail of binary
      // rounding, which is not a measurement anybody made.
      "the value is the measurement, not the float that carried it"
    );
    assert.strictEqual(formatMs(12.34), "12.3");
    assert.strictEqual(
      formatMs(99.4),
      "99.4",
      "99.4 is below the rounding cut"
    );
  });

  test("a whole number of milliseconds does not grow a decimal", function (assert) {
    assert.strictEqual(formatMs(12), "12");
    assert.strictEqual(formatMs(42), "42");
    assert.strictEqual(
      formatMs(0),
      "0",
      "a subscriber that has never been called reads as a plain zero"
    );
  });

  test("payloads are pretty printed", function (assert) {
    const data = { alpha: 1, beta: [1, 2], gamma: { nested: true } };

    assert.strictEqual(prettyJson(data), JSON.stringify(data, null, 2));
    assert.true(
      prettyJson(data).includes("\n"),
      "the payload is indented over several lines rather than inlined"
    );
    assert.strictEqual(prettyJson(null), "null");
    assert.strictEqual(prettyJson("plain"), '"plain"');
  });

  test("a payload JSON cannot represent falls back to its string form", function (assert) {
    const circular = { name: "loop" };
    circular.self = circular;

    const formatted = prettyJson(circular);

    assert.strictEqual(
      typeof formatted,
      "string",
      "a circular payload is described rather than thrown over"
    );
    assert.strictEqual(formatted, String(circular));

    assert.strictEqual(
      prettyJson(undefined),
      String(undefined),
      "stringify returning undefined is also a failure to represent"
    );
  });

  test("a named stack frame is reduced to its function and file position", function (assert) {
    const frame =
      "    at myFunction (http://localhost:3000/assets/discourse/app/lib/foo.js:123:45)";
    const label = shortSource(frame);

    assert.true(label.includes("myFunction"), "the caller is named");
    assert.true(
      label.includes("foo.js"),
      "the file is named, without its path"
    );
    assert.true(label.includes("123"), "the line is kept");
    assert.false(
      label.includes("http://"),
      "the origin is noise in a panel this narrow"
    );
    assert.false(label.includes(":45"), "the column is dropped");
  });

  test("an anonymous stack frame keeps its file position", function (assert) {
    const label = shortSource("    at http://localhost:3000/assets/bar.js:7:1");

    assert.true(label.includes("bar.js"));
    assert.true(label.includes("7"));
    assert.false(label.includes("http://"));
  });

  test("an absent frame has no label", function (assert) {
    assert.strictEqual(shortSource(null), null);
    assert.strictEqual(
      shortSource(undefined),
      null,
      "a subscription captured before dev tools loaded has no frame to shorten"
    );
  });

  test("an unrecognizable frame is passed through trimmed", function (assert) {
    assert.strictEqual(
      shortSource("   <anonymous>   "),
      "<anonymous>",
      "an unfamiliar engine's frame is still worth showing verbatim"
    );
  });

  test("a preview says what a payload holds without leaving one line", function (assert) {
    const preview = messagePreview(
      observed({
        marker: "unique-marker-123",
        nested: { deep: [1, 2] },
      })
    );

    assert.strictEqual(typeof preview, "string");
    assert.true(
      preview.includes("unique-marker-123"),
      "the content that distinguishes one message from another survives"
    );
    assert.false(
      preview.includes("\n"),
      "a stream row is one line, so the preview never brings its own"
    );
  });

  test("a preview is computed once per message", function (assert) {
    const message = observed({ marker: "unique-marker-123" });
    const first = messagePreview(message);

    assert.strictEqual(
      messagePreview(message),
      first,
      "the same message yields the same preview"
    );

    message.data = { marker: "rewritten-marker" };

    assert.strictEqual(
      messagePreview(message),
      first,
      // Payloads are retained by reference, so a subscriber mutating one later
      // would otherwise re-render every stream row it appears in.
      "the preview is cached against the message rather than recomputed"
    );

    assert.true(
      messagePreview(observed({ marker: "another-marker" })).includes(
        "another-marker"
      ),
      "the cache is per message, not a single shared slot"
    );
  });

  test("a message reports the byte size of its payload", function (assert) {
    assert.strictEqual(
      messageBytes(observed({ marker: "unique-marker-123" })),
      30,
      'the size is that of {"marker":"unique-marker-123"}'
    );
    assert.strictEqual(
      messageBytes(observed({ marker: "héllo 😀" })),
      24,
      "the size is counted in bytes on the wire, not in JavaScript characters"
    );
  });

  test("a message size is computed once per message", function (assert) {
    const message = observed({ marker: "unique-marker-123" });
    const first = messageBytes(message);

    assert.strictEqual(messageBytes(message), first);

    message.data = { marker: "a-much-much-much-longer-marker-value" };

    assert.strictEqual(
      messageBytes(message),
      first,
      "the size is cached against the message rather than recomputed"
    );

    assert.strictEqual(
      messageBytes(observed({})),
      2,
      "the cache is per message, not a single shared slot"
    );
  });
});
