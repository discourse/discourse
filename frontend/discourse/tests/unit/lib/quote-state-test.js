import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  getExtensions,
  registerRichEditorExtension,
} from "discourse/lib/composer/rich-editor-extensions";
import QuoteState from "discourse/lib/quote-state";
import defaultExtensions from "discourse/static/prosemirror/extensions/register-default";

module("Unit | Utility | quote-state", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    if (!getExtensions().length) {
      defaultExtensions.forEach(registerRichEditorExtension);
    }
  });

  test("buffer derives plain text from the selected HTML", function (assert) {
    const state = new QuoteState();
    state.selected(
      1,
      null,
      { username: "u" },
      "<p><b>bold</b> word</p>",
      "<p><b>bold</b> word</p>"
    );

    assert.strictEqual(state.buffer, "bold word");
    assert.strictEqual(state.postId, 1);
    assert.deepEqual(state.opts, { username: "u" });
  });

  test("markdown() converts selected HTML to markdown", async function (assert) {
    const state = new QuoteState();
    state.selected(
      1,
      null,
      { username: "u" },
      "<p><b>bold</b></p>",
      "<p><b>bold</b></p>"
    );

    const result = await state.markdown();
    assert.strictEqual(result.markdown, "**bold**");
    assert.strictEqual(result.opts.username, "u");
    assert.true(result.opts.full, "full is true when selection covers cooked");
  });

  test("markdown() returns full:false when selection differs from cooked", async function (assert) {
    const state = new QuoteState();
    state.selected(
      1,
      null,
      { username: "u" },
      "<p><b>bold</b></p>",
      "<p><b>bold</b> and more</p>"
    );

    const result = await state.markdown();
    assert.strictEqual(result.markdown, "**bold**");
    assert.false(result.opts.full);
  });

  test("markdown() snapshots opts before awaiting so a concurrent selected() does not poison the result", async function (assert) {
    const state = new QuoteState();
    state.selected(
      1,
      null,
      { username: "alice", post: 1, topic: 1 },
      "<p><b>bold</b></p>",
      "<p><b>bold</b></p>"
    );

    const inflight = state.markdown();
    state.selected(
      2,
      null,
      { username: "bob", post: 2, topic: 2 },
      "<p><i>italic</i></p>",
      "<p><i>italic</i></p>"
    );

    const result = await inflight;
    assert.strictEqual(
      result.opts.username,
      "alice",
      "opts came from the selection that triggered markdown()"
    );
    assert.strictEqual(result.opts.post, 1);
    assert.strictEqual(result.opts.topic, 1);
  });

  test("markdown() does not mutate the caller's opts object", async function (assert) {
    const state = new QuoteState();
    const originalOpts = { username: "u" };
    state.selected(
      1,
      null,
      originalOpts,
      "<p><b>bold</b></p>",
      "<p><b>bold</b></p>"
    );

    const result = await state.markdown();
    assert.true(result.opts.full);
    assert.strictEqual(
      originalOpts.full,
      undefined,
      "caller's opts object is unchanged after markdown()"
    );
  });

  test("copyFrom() transfers the full selection state from another QuoteState", async function (assert) {
    const source = new QuoteState();
    source.selected(
      1,
      null,
      { username: "u" },
      "<p><b>bold</b></p>",
      "<p><b>bold</b></p>"
    );

    const target = new QuoteState();
    target.copyFrom(source);

    assert.strictEqual(target.postId, 1);
    assert.strictEqual(target.buffer, "bold");

    const result = await target.markdown();
    assert.strictEqual(
      result.markdown,
      "**bold**",
      "target also has selectedHtml so markdown() converts it"
    );
    assert.true(result.opts.full);
  });

  test("clear() resets all state", function (assert) {
    const state = new QuoteState();
    state.selected(1, null, { a: 1 }, "<p>x</p>", "<p>x</p>");
    state.clear();

    assert.strictEqual(state.postId, null);
    assert.strictEqual(state.buffer, "");
    assert.strictEqual(state.opts, null);
  });

  test("an inflight markdown() promise survives a concurrent clear()", async function (assert) {
    const state = new QuoteState();
    state.selected(
      1,
      null,
      { username: "alice", post: 1, topic: 1 },
      "<p><b>bold</b></p>",
      "<p><b>bold</b></p>"
    );

    const inflight = state.markdown();
    state.clear();

    const result = await inflight;
    assert.strictEqual(result.markdown, "**bold**");
    assert.strictEqual(result.opts.username, "alice");
  });
});
