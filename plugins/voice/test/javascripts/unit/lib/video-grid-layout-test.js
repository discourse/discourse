import { module, test } from "qunit";
import {
  bestRowHeight,
  computeWidgetGrid,
  DEFAULT_TILE_ASPECT,
} from "discourse/plugins/voice/discourse/lib/voice/video-grid-layout";

const LANDSCAPE = DEFAULT_TILE_ASPECT; // 16 / 9
const PORTRAIT = 9 / 16;

module("Voice | Unit | Lib | video-grid-layout", function () {
  test("a single tile fills the constraining dimension", function (assert) {
    // Wide container: a landscape tile is limited by height.
    assert.strictEqual(
      bestRowHeight(4000, 900, [LANDSCAPE], 0),
      900,
      "height-limited single landscape tile spans the full height"
    );

    // Narrow container: limited by width.
    assert.strictEqual(
      bestRowHeight(1000, 4000, [LANDSCAPE], 0),
      562,
      "width-limited single landscape tile spans the full width"
    );
  });

  test("a portrait tile fills the height of a landscape container", function (assert) {
    const height = bestRowHeight(1920, 1080, [PORTRAIT], 0);
    assert.strictEqual(
      height,
      1080,
      "portrait tile uses the full height instead of being letterboxed"
    );
    assert.true(
      height * PORTRAIT <= 1920,
      "and stays within the container width"
    );
  });

  test("more tiles shrink the row height without overflowing", function (assert) {
    const width = 1920;
    const height = 1080;
    const counts = [1, 2, 4, 9];

    const heights = counts.map((count) =>
      bestRowHeight(width, height, Array(count).fill(LANDSCAPE), 8)
    );

    assert.deepEqual(
      [...heights].sort((a, b) => b - a),
      heights,
      "row height is monotonically non-increasing as tiles are added"
    );

    heights.forEach((rowHeight, index) => {
      assert.true(rowHeight > 0, `${counts[index]} tiles get a usable height`);
      assert.true(
        rowHeight <= height,
        `${counts[index]} tiles fit within the container height`
      );
    });
  });

  test("mixed portrait and landscape tiles share a row at a common height", function (assert) {
    const rowHeight = bestRowHeight(1920, 1080, [LANDSCAPE, PORTRAIT], 8);

    // One row beats stacking (which would cap height near 536), so the shared
    // height lands well above that.
    assert.true(rowHeight > 600, "lays the two tiles out side by side");

    const totalWidth = rowHeight * LANDSCAPE + 8 + rowHeight * PORTRAIT;
    assert.true(
      totalWidth <= 1920,
      "the mixed-aspect row fits the container width"
    );
  });

  test("returns zero when nothing can fit", function (assert) {
    assert.strictEqual(
      bestRowHeight(10, 10, Array(50).fill(LANDSCAPE), 8),
      0,
      "degenerate space yields no usable height"
    );
  });
});

module("Voice | Unit | Lib | video-grid-layout | widget grid", function () {
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
