import { module, test } from "qunit";
import {
  markBBCodeTags,
  scanBBCodeTags,
} from "discourse-markdown-it/bbcode-rewriter";

module("Unit | Utility | BBCode rewriter", function () {
  test("does not repeatedly copy the remaining post for bracket decoys", function (assert) {
    const opening = '[event start="2026-11-07 12:00" timezone="UTC"]';
    const raw = `\`\`\`\n${"[".repeat(128)}\n\`\`\`\n${opening}\n[/event]`;

    let slicedCharacters = 0;

    // Instrument only this input, without altering String.prototype.
    const measuredRaw = new Proxy(Object(raw), {
      get(target, property) {
        if (property === "slice") {
          return (...args) => {
            const result = raw.slice(...args);
            slicedCharacters += result.length;
            return result;
          };
        }

        const value = Reflect.get(target, property);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });

    const candidates = scanBBCodeTags(measuredRaw, "event");

    assert.strictEqual(candidates.length, 1);
    assert.strictEqual(candidates[0].opening, opening);
    assert.true(
      slicedCharacters < raw.length * 8,
      `Scanner copied ${slicedCharacters} characters from ${raw.length} characters of input`
    );
  });

  test("marks multiple tags without treating quoted brackets as new tags", function (assert) {
    const raw = '[event name="A [event] room"]\n[event name="B"]';

    const marked = markBBCodeTags(raw, "event", "bbcoderewriterabc", "marker");

    assert.strictEqual(
      marked,
      '[event name="A [event] room" bbcoderewriterabc=marker-0]\n' +
        '[event name="B" bbcoderewriterabc=marker-1]'
    );
  });

  test("avoids copying for plausible bracket decoys", function (assert) {
    const opening = '[event name="OK"]';
    const raw = `${"[a".repeat(128)}${opening}`;
    let copiedCharacters = 0;

    const measuredRaw = new Proxy(Object(raw), {
      get(target, property) {
        if (property === "slice") {
          return (...args) => {
            const result = raw.slice(...args);
            copiedCharacters += result.length;
            return result;
          };
        }

        const value = Reflect.get(target, property);
        return typeof value === "function" ? value.bind(target) : value;
      },
    });

    const candidates = scanBBCodeTags(measuredRaw, "event");

    assert.strictEqual(candidates.length, 1);
    assert.strictEqual(candidates[0]?.opening, opening);
    assert.true(
      copiedCharacters < raw.length * 8,
      `Copied ${copiedCharacters} characters from ${raw.length} characters`
    );
  });

  test("recognizes long valid opening tags", function (assert) {
    const opening = `[event name="${"x".repeat(9000)}"]`;
    const candidates = scanBBCodeTags(opening, "event");

    assert.strictEqual(candidates.length, 1);
    assert.strictEqual(candidates[0]?.opening, opening);
  });
});
