import { module, test } from "qunit";
import { createSchema } from "discourse/static/prosemirror/core/schema";
import {
  findChangeByCoords,
  fragmentHasVisibleContent,
  sliceIsBlockLevel,
} from "discourse/static/prosemirror/lib/inline-diff-fragment";

const schema = createSchema([]);

const text = (value) => schema.text(value);
const para = (...content) => schema.node("paragraph", null, content);
const doc = (...content) => schema.node("doc", null, content);
// Image is an inline leaf in the default markdown schema — stands in for
// mentions/emoji/etc. in these tests.
const leaf = (src = "x") => schema.node("image", { src });

module("Unit | Utility | inline-diff-fragment", function () {
  module("sliceIsBlockLevel", function () {
    test("returns false for null/undefined fragment", function (assert) {
      assert.false(sliceIsBlockLevel(null));
      assert.false(sliceIsBlockLevel(undefined));
    });

    test("returns false for inline-only fragment (plain text)", function (assert) {
      const fragment = para(text("hello world")).content;
      assert.false(sliceIsBlockLevel(fragment));
    });

    test("returns false for inline-only fragment with leaves", function (assert) {
      const fragment = para(
        text("hi "),
        leaf("mention"),
        text(" there")
      ).content;
      assert.false(sliceIsBlockLevel(fragment));
    });

    test("returns true when fragment contains a block node", function (assert) {
      const fragment = doc(para(text("a")), para(text("b"))).content;
      assert.true(sliceIsBlockLevel(fragment));
    });
  });

  module("fragmentHasVisibleContent", function () {
    test("returns false for null/undefined fragment", function (assert) {
      assert.false(fragmentHasVisibleContent(null));
      assert.false(fragmentHasVisibleContent(undefined));
    });

    test("returns false for zero-size fragment", function (assert) {
      const fragment = para().content;
      assert.strictEqual(fragment.size, 0);
      assert.false(fragmentHasVisibleContent(fragment));
    });

    test("returns true for fragment with text", function (assert) {
      const fragment = para(text("hi")).content;
      assert.true(fragmentHasVisibleContent(fragment));
    });

    test("returns true for fragment with only an inline leaf", function (assert) {
      const fragment = para(leaf("emoji")).content;
      assert.true(fragmentHasVisibleContent(fragment));
    });

    test("returns true for nested block fragment with text", function (assert) {
      const fragment = doc(para(text("hello"))).content;
      assert.true(fragmentHasVisibleContent(fragment));
    });

    test("returns false for fragment that is purely structural", function (assert) {
      // A doc that contains only an empty paragraph (no text, no leaves) —
      // this is what a split-block step produces when it inserts a fresh
      // textblock boundary without any user content.
      const fragment = doc(para()).content;
      assert.false(fragmentHasVisibleContent(fragment));
    });
  });

  module("findChangeByCoords", function () {
    const change = (fromA, toA, fromB, toB) => ({ fromA, toA, fromB, toB });

    test("returns null for empty or nullish changes", function (assert) {
      assert.strictEqual(findChangeByCoords(null, change(0, 0, 0, 0)), null);
      assert.strictEqual(findChangeByCoords([], change(0, 0, 0, 0)), null);
    });

    test("returns the exact-match change when coords align", function (assert) {
      const c1 = change(5, 10, 5, 12);
      const c2 = change(20, 25, 22, 27);
      const result = findChangeByCoords([c1, c2], change(20, 25, 22, 27));
      assert.strictEqual(result, c2);
    });

    test("returns null when no change matches", function (assert) {
      const c1 = change(5, 10, 5, 12);
      assert.strictEqual(
        findChangeByCoords([c1], change(100, 105, 100, 105)),
        null
      );
    });

    test("falls back to containment when exact match fails", function (assert) {
      // Simulates a button rendered for change (5,10,5,10) whose change has
      // since been merged into a wider change (0,20,0,20) by the changeset's
      // default `combine` fn.
      const merged = change(0, 20, 0, 20);
      const result = findChangeByCoords([merged], change(5, 10, 5, 10));
      assert.strictEqual(result, merged);
    });

    test("prefers exact match over a wider containing change", function (assert) {
      const wide = change(0, 20, 0, 20);
      const exact = change(5, 10, 5, 10);
      const result = findChangeByCoords([wide, exact], change(5, 10, 5, 10));
      assert.strictEqual(result, exact);
    });

    test("returns null when containing candidate covers only one side", function (assert) {
      // Covers A side but not B — not a safe match.
      const partial = change(0, 20, 100, 200);
      const result = findChangeByCoords([partial], change(5, 10, 5, 10));
      assert.strictEqual(result, null);
    });
  });
});
