import { module, test } from "qunit";
import {
  gridDimensions,
  normalizeFractions,
  parsePlacement,
  parseSlotPlacement,
  parseTrack,
} from "discourse/lib/blocks/-internals/grid-placement";

function gridChild(column, row) {
  return { containerArgs: { grid: { column, row } } };
}

module("Unit | Lib | blocks | grid-placement", function () {
  module("parseTrack", function () {
    test("parses N / M as {start, end}", function (assert) {
      assert.deepEqual(parseTrack("1 / 4"), { start: 1, end: 4 });
    });

    test("parses single number as {N, N+1}", function (assert) {
      assert.deepEqual(parseTrack("3"), { start: 3, end: 4 });
    });

    test("returns nulls for auto", function (assert) {
      assert.deepEqual(parseTrack("auto"), { start: null, end: null });
    });

    test("returns nulls for missing / undefined / span shorthand", function (assert) {
      assert.deepEqual(parseTrack(undefined), { start: null, end: null });
      assert.deepEqual(parseTrack(""), { start: null, end: null });
      assert.deepEqual(parseTrack("span 2"), { start: null, end: null });
    });

    test("coerces invalid end value to span 1", function (assert) {
      assert.deepEqual(parseTrack("3 / 2"), { start: 3, end: 4 });
    });
  });

  module("parseSlotPlacement", function () {
    test("parses both axes", function (assert) {
      assert.deepEqual(parseSlotPlacement({ column: "1 / 3", row: "2" }), {
        column: { start: 1, end: 3 },
        row: { start: 2, end: 3 },
      });
    });

    test("handles missing args", function (assert) {
      assert.deepEqual(parseSlotPlacement({}), {
        column: { start: null, end: null },
        row: { start: null, end: null },
      });
    });
  });

  module("parsePlacement", function () {
    test("reads placement from containerArgs.grid", function (assert) {
      assert.deepEqual(
        parsePlacement({ grid: { column: "1 / 3", row: "2" } }),
        {
          column: { start: 1, end: 3 },
          row: { start: 2, end: 3 },
        }
      );
    });

    test("returns null tracks for missing container args", function (assert) {
      assert.deepEqual(parsePlacement(undefined), {
        column: { start: null, end: null },
        row: { start: null, end: null },
      });
    });
  });

  module("gridDimensions", function () {
    test("uses the declared size when the content fits", function (assert) {
      assert.deepEqual(gridDimensions({ columns: 3, rows: 2 }, []), {
        columns: 3,
        rows: 2,
      });
    });

    test("grows to contain a child that spans past the declared size", function (assert) {
      assert.deepEqual(
        gridDimensions({ columns: 1, rows: 1 }, [gridChild("2 / 4", "1 / 3")]),
        { columns: 3, rows: 2 }
      );
    });

    test("a single-cell child counts its own column / row", function (assert) {
      assert.deepEqual(
        gridDimensions({ columns: 1, rows: 1 }, [gridChild("3", "2")]),
        { columns: 3, rows: 2 }
      );
    });

    test("ignores auto-placed children", function (assert) {
      assert.deepEqual(
        gridDimensions({ columns: 2, rows: 2 }, [gridChild("auto", "auto")]),
        { columns: 2, rows: 2 }
      );
    });

    test("the reported regression: a callout at 2/4 · 1/3 in a rows:3 grid with no declared columns", function (assert) {
      // The grid declared `rows: 3` and no `columns`; the caller defaults
      // columns to 3. The callout spans columns 2-3 (needs 3) and rows 1-2
      // (needs 2). Effective size must be the 3×3 the grid actually is —
      // not a bare default that disagrees with the rendered grid.
      assert.deepEqual(
        gridDimensions({ columns: 3, rows: 3 }, [gridChild("2 / 4", "1 / 3")]),
        { columns: 3, rows: 3 }
      );
    });

    test("treats a missing declared size as a single track before content", function (assert) {
      assert.deepEqual(gridDimensions({}, [gridChild("1 / 5", "1")]), {
        columns: 4,
        rows: 1,
      });
    });
  });

  module("normalizeFractions", function () {
    test("returns the values unchanged when the count matches", function (assert) {
      assert.deepEqual(normalizeFractions([1, 2, 1], 3), [1, 2, 1]);
    });

    test("pads a short array with 1fr tracks", function (assert) {
      assert.deepEqual(normalizeFractions([2, 1], 4), [2, 1, 1, 1]);
    });

    test("truncates a long array", function (assert) {
      assert.deepEqual(normalizeFractions([1, 2, 3, 4], 2), [1, 2]);
    });

    test("falls back to 1 for missing / non-positive / non-finite entries", function (assert) {
      assert.deepEqual(normalizeFractions([0, -1, "x"], 3), [1, 1, 1]);
      assert.deepEqual(normalizeFractions(undefined, 2), [1, 1]);
    });
  });
});
