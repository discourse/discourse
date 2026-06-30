import { module, test } from "qunit";
import { richInlineToPlainText } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/walk-layout";

// `richInlineToPlainText` flattens a rich text arg value (a tab's label,
// for instance) to plain text for the outline chip. The value is either a plain
// string or doc JSON with a `content` array of runs.
module("Unit | Discourse Wireframe | walk-layout", function () {
  test("richInlineToPlainText: plain string passes through", function (assert) {
    assert.strictEqual(richInlineToPlainText("Pricing"), "Pricing");
  });

  test("richInlineToPlainText: joins the text runs of doc JSON", function (assert) {
    const doc = {
      content: [
        { type: "text", text: "Sign " },
        { type: "text", text: "up" },
      ],
    };
    assert.strictEqual(richInlineToPlainText(doc), "Sign up");
  });

  test("richInlineToPlainText: ignores non-text runs", function (assert) {
    const doc = {
      content: [
        { type: "text", text: "Hi" },
        { type: "hardBreak" },
        { type: "text" },
      ],
    };
    assert.strictEqual(richInlineToPlainText(doc), "Hi");
  });

  test("richInlineToPlainText: empty / unrecognised values yield an empty string", function (assert) {
    assert.strictEqual(richInlineToPlainText(null), "");
    assert.strictEqual(richInlineToPlainText(undefined), "");
    assert.strictEqual(richInlineToPlainText({}), "");
    assert.strictEqual(richInlineToPlainText(""), "");
  });
});
