import { module, test } from "qunit";
import { reactionGridColumns } from "discourse/plugins/live/discourse/lib/live/reaction-grid";

module("Live | Unit | Lib | reaction-grid", function () {
  test("keeps a short set on one row", function (assert) {
    assert.strictEqual(reactionGridColumns(3), 3);
    assert.strictEqual(reactionGridColumns(4), 4);
  });

  test("wraps at a column count that fills the rows evenly", function (assert) {
    assert.strictEqual(reactionGridColumns(10), 5);
    assert.strictEqual(reactionGridColumns(12), 6);
    assert.strictEqual(reactionGridColumns(14), 7);
  });

  test("prefers a fuller last row when nothing divides evenly", function (assert) {
    // 9 → rests 4 (5), 3 (6), 2 (7): five columns leaves the fullest last row.
    assert.strictEqual(reactionGridColumns(9), 5);
    // 13 → rests 3 (5), 1 (6), 6 (7): seven columns leaves the fullest last row.
    assert.strictEqual(reactionGridColumns(13), 7);
  });

  test("allows eight columns only on wider screens", function (assert) {
    assert.strictEqual(reactionGridColumns(16), 6);
    assert.strictEqual(reactionGridColumns(16, { wide: true }), 8);
  });
});
