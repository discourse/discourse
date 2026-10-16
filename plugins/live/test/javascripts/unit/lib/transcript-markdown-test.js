import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { transcriptToMarkdown } from "discourse/plugins/live/discourse/lib/live/transcript-markdown";

module("Live | Unit | Lib | transcript-markdown", function (hooks) {
  setupTest(hooks);

  const entries = [
    {
      utteranceId: 7,
      userId: 42,
      username: "alice",
      text: "hello world",
      startedAt: Date.UTC(2026, 7, 20, 16, 38, 24),
    },
    {
      utteranceId: 8,
      userId: 43,
      username: "bob",
      text: "hi there",
      startedAt: Date.UTC(2026, 7, 20, 16, 38, 46),
    },
  ];

  test("renders chained chat transcript markup", function (assert) {
    const markdown = transcriptToMarkdown(entries);

    assert.strictEqual(
      markdown,
      [
        '[chat quote="alice;7;2026-08-20T16:38:24.000Z" chained="true"]\nhello world\n[/chat]',
        '[chat quote="bob;8;2026-08-20T16:38:46.000Z" chained="true"]\nhi there\n[/chat]',
      ].join("\n\n")
    );
  });

  test("names the room as the source on the first entry only", function (assert) {
    const markdown = transcriptToMarkdown(entries, { roomName: "Weekly sync" });

    assert.strictEqual(
      markdown,
      [
        '[chat quote="alice;7;2026-08-20T16:38:24.000Z" source="Weekly sync" sourceType=live chained="true"]\nhello world\n[/chat]',
        '[chat quote="bob;8;2026-08-20T16:38:46.000Z" chained="true"]\nhi there\n[/chat]',
      ].join("\n\n")
    );
  });

  test("keeps a room name with quotes in one attribute", function (assert) {
    const markdown = transcriptToMarkdown(entries, {
      roomName: 'The "big" room',
    });

    assert.true(markdown.includes(` source='The "big" room' `));
  });

  test("falls back to plain quotes without chat markup", function (assert) {
    const markdown = transcriptToMarkdown(entries, { chatMarkup: false });

    assert.strictEqual(
      markdown,
      [
        '[quote="alice"]\nhello world\n[/quote]',
        '[quote="bob"]\nhi there\n[/quote]',
      ].join("\n\n")
    );
  });

  test("a missing username gets a placeholder", function (assert) {
    const markdown = transcriptToMarkdown([
      { utteranceId: 9, text: "who dis", startedAt: 0 },
    ]);

    assert.false(markdown.includes('"undefined;'));
    assert.true(markdown.startsWith("[chat quote="));
  });
});
