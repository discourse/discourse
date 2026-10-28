import { module, test } from "qunit";
import {
  computeRoomGrid,
  computeWidgetGrid,
  DEFAULT_TILE_ASPECT,
} from "discourse/plugins/live/discourse/lib/live/video-grid-layout";

module("Live | Unit | Lib | video-grid-layout | room grid", function () {
  test("a lone tile fills the box up to a landscape aspect", function (assert) {
    const grid = computeRoomGrid({
      width: 1423,
      height: 719,
      count: 1,
      gap: 8,
    });
    assert.strictEqual(grid.tileHeight, 719, "spans the full height");
    assert.strictEqual(
      grid.tileWidth,
      Math.floor(719 * DEFAULT_TILE_ASPECT),
      "and stops widening at 16:9"
    );
  });

  test("two tiles crop toward square instead of leaving empty bands", function (assert) {
    const grid = computeRoomGrid({
      width: 1423,
      height: 719,
      count: 2,
      gap: 8,
    });
    assert.strictEqual(grid.cols, 2, "sit side by side");
    assert.strictEqual(grid.tileWidth, 707, "fill their half of the width");
    assert.strictEqual(grid.tileHeight, 707, "at a square aspect");
  });

  test("prefers a full row over a slightly larger ragged layout", function (assert) {
    // 2+1 gives a marginally larger tile here; three across is within
    // tolerance and leaves no orphan.
    const grid = computeRoomGrid({
      width: 1423,
      height: 719,
      count: 3,
      gap: 8,
    });
    assert.strictEqual(grid.cols, 3, "three across");
    assert.strictEqual(grid.rows, 1, "in one row");
  });

  test("tiles always fit the box and lines break at the solved column count", function (assert) {
    const gap = 8;
    const boxes = [
      { width: 1423, height: 719 },
      { width: 1151, height: 719 },
      { width: 799, height: 719 },
      { width: 360, height: 640 },
      { width: 1903, height: 899 },
    ];

    for (const { width, height } of boxes) {
      for (let count = 1; count <= 16; count++) {
        const grid = computeRoomGrid({ width, height, count, gap });
        const label = `${count} in ${width}×${height}`;
        const { cols, rows, tileWidth, tileHeight, lineWidth } = grid;

        assert.true(
          cols * tileWidth + (cols - 1) * gap <= width,
          `${label}: fits the width`
        );
        assert.true(
          rows * tileHeight + (rows - 1) * gap <= height,
          `${label}: fits the height`
        );
        assert.true(
          cols * tileWidth + (cols - 1) * gap <= lineWidth,
          `${label}: a full line fits the line width`
        );
        assert.true(
          (cols + 1) * tileWidth + cols * gap > lineWidth,
          `${label}: an extra tile never fits the line width`
        );
      }
    }
  });

  test("returns null for degenerate input", function (assert) {
    assert.strictEqual(
      computeRoomGrid({ width: 1000, height: 600, count: 0, gap: 8 }),
      null,
      "no tiles"
    );
    assert.strictEqual(
      computeRoomGrid({ width: 0, height: 600, count: 3, gap: 8 }),
      null,
      "no measured space"
    );
    assert.strictEqual(
      computeRoomGrid({ width: 10, height: 10, count: 50, gap: 8 }),
      null,
      "no room for any cell"
    );
  });
});

module("Live | Unit | Lib | video-grid-layout | widget grid", function () {
  test("a lone participant fills the box, aspect permitting", function (assert) {
    assert.deepEqual(
      computeWidgetGrid({ width: 400, height: 300, count: 1, gap: 8 }),
      {
        shown: 1,
        overflow: 0,
        cols: 1,
        rows: 1,
        tileWidth: 400,
        tileHeight: 300,
      },
      "a 4:3 box is within the aspect band, so the tile takes all of it"
    );
  });

  test("shows everyone in the largest-tile arrangement when they fit", function (assert) {
    assert.deepEqual(
      computeWidgetGrid({ width: 400, height: 300, count: 4, gap: 8 }),
      {
        shown: 4,
        overflow: 0,
        cols: 2,
        rows: 2,
        tileWidth: 196,
        tileHeight: 146,
      },
      "four participants get a 2×2 grid of cell-filling tiles"
    );
  });

  test("collapses a crowd into an overflow slot when tiles would go illegible", function (assert) {
    assert.deepEqual(
      computeWidgetGrid({ width: 360, height: 200, count: 12, gap: 8 }),
      {
        shown: 5,
        overflow: 7,
        cols: 3,
        rows: 2,
        tileWidth: 114,
        tileHeight: 86,
      },
      "drops to the six-slot arrangement: five participants plus the overflow tile"
    );
  });

  test("never hides exactly one participant", function (assert) {
    const boxes = [
      { width: 360, height: 200 },
      { width: 300, height: 150 },
      { width: 800, height: 600 },
      { width: 150, height: 100 },
    ];

    for (const { width, height } of boxes) {
      for (let count = 1; count <= 30; count++) {
        const layout = computeWidgetGrid({ width, height, count, gap: 8 });
        assert.notStrictEqual(
          layout.overflow,
          1,
          `${count} in ${width}×${height}: overflow of ${layout.overflow} is never one`
        );
        assert.strictEqual(
          layout.shown + layout.overflow,
          count,
          `${count} in ${width}×${height}: everyone is shown or counted`
        );
        assert.true(
          layout.shown >= 1,
          `${count} in ${width}×${height}: at least one participant stays visible`
        );
      }
    }
  });

  test("flooring never lets an extra tile squeeze onto a row", function (assert) {
    // 366×140 at gap 7.5 floors the 2×2 tile to 117px — exactly three of
    // which would fit one flex row (3×117 + 2×7.5 = 366) without the guard,
    // rendering 3+1 instead of the solved grid.
    const layout = computeWidgetGrid({
      width: 366,
      height: 140,
      count: 4,
      gap: 7.5,
    });
    assert.strictEqual(layout.cols, 2, "solves a 2×2");
    assert.true(
      layout.tileWidth * 3 + 2 * 7.5 > 366,
      "three tiles cannot share a row"
    );
    assert.true(
      layout.tileWidth * 2 + 7.5 <= 366,
      "two tiles still fit their row"
    );
  });

  test("caps visible slots even with room to spare", function (assert) {
    const layout = computeWidgetGrid({
      width: 2000,
      height: 1500,
      count: 40,
      gap: 8,
    });
    assert.strictEqual(layout.shown, 11, "eleven participants plus overflow");
    assert.strictEqual(layout.overflow, 29, "the rest collapse into the count");
  });

  test("yields the legibility floor rather than vanishing in a tiny box", function (assert) {
    const layout = computeWidgetGrid({
      width: 150,
      height: 100,
      count: 6,
      gap: 8,
    });
    assert.strictEqual(layout.shown, 1, "keeps one participant visible");
    assert.strictEqual(layout.overflow, 5, "counts the rest");
    assert.true(layout.tileWidth > 0, "with a usable tile size");
  });

  test("returns null for degenerate input", function (assert) {
    assert.strictEqual(
      computeWidgetGrid({ width: 400, height: 300, count: 0, gap: 8 }),
      null,
      "no participants"
    );
    assert.strictEqual(
      computeWidgetGrid({ width: 0, height: 300, count: 4, gap: 8 }),
      null,
      "no measured space"
    );
  });
});
