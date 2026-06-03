import { module, test } from "qunit";
import {
  cellAt,
  computeOccupation,
  computeShiftPlan,
  computeZone,
  computeZoneCollapsed,
  formatTrack,
  reflowChildrenIntoSpaces,
  spacesForFree,
  syncContentToArrayOrder,
  unoccupiedCells,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";

// A grid cell fixture. `entryKey` (used internally by computeShiftPlan) keys
// an entry as `"${block}:${__stableKey}"`, so a cell named "k" resolves to
// the key "wf:cell:k". `column` / `row` accept CSS Grid shorthand ("2",
// "1 / 3", "auto").
function slot(key, column, row) {
  return {
    __stableKey: key,
    block: "wf:cell",
    containerArgs: { grid: { column, row } },
  };
}

function keyOf(k) {
  return `wf:cell:${k}`;
}

// The placement *parsers* (parseTrack / parseSlotPlacement / parsePlacement)
// now live in core and are covered by core's grid-placement test. What's
// exercised here is the editor-only geometry that stays in the plugin.
module("Unit | Discourse Wireframe | lib:grid-math", function () {
  module("formatTrack", function () {
    test("auto", function (assert) {
      assert.strictEqual(formatTrack({ start: null, end: null }), "auto");
    });

    test("single line", function (assert) {
      assert.strictEqual(formatTrack({ start: 3, end: 4 }), "3");
    });

    test("span N", function (assert) {
      assert.strictEqual(formatTrack({ start: 1, end: 4 }), "1 / 4");
    });
  });

  module("computeOccupation", function () {
    test("marks explicit placements", function (assert) {
      const slots = [
        { containerArgs: { grid: { column: "1 / 3", row: "1" } } },
        { containerArgs: { grid: { column: "3", row: "1" } } },
      ];
      const occupied = computeOccupation(slots, 4, 2);
      assert.true(occupied.has("1,1"));
      assert.true(occupied.has("1,2"));
      assert.true(occupied.has("1,3"));
      assert.false(occupied.has("1,4"));
      assert.false(occupied.has("2,1"));
    });

    test("auto-places remaining slots in row-major order", function (assert) {
      const slots = [
        { containerArgs: { grid: { column: "1", row: "1" } } },
        { containerArgs: { grid: { column: "auto", row: "auto" } } },
      ];
      const occupied = computeOccupation(slots, 3, 1);
      assert.true(occupied.has("1,1"));
      assert.true(occupied.has("1,2"));
    });
  });

  module("unoccupiedCells", function () {
    test("returns every uncovered cell, row-major", function (assert) {
      const occupied = new Set(["1,1"]);
      const cells = unoccupiedCells(occupied, 2, 2);
      assert.deepEqual(cells, [
        { column: 2, row: 1 },
        { column: 1, row: 2 },
        { column: 2, row: 2 },
      ]);
    });
  });

  module("cellAt", function () {
    test("maps pointer position to a 1-indexed cell", function (assert) {
      const gridRect = { left: 0, top: 0, width: 400, height: 200 };
      const event = { clientX: 250, clientY: 150 };
      assert.deepEqual(cellAt(event, gridRect, 4, 2), { column: 3, row: 2 });
    });

    test("clamps to grid bounds", function (assert) {
      const gridRect = { left: 0, top: 0, width: 400, height: 200 };
      assert.deepEqual(
        cellAt({ clientX: 9999, clientY: 9999 }, gridRect, 4, 2),
        { column: 4, row: 2 }
      );
      assert.deepEqual(cellAt({ clientX: -10, clientY: -10 }, gridRect, 4, 2), {
        column: 1,
        row: 1,
      });
    });
  });

  module("computeOccupation — auto-flow overflow", function () {
    test("stops auto-placing once the grid is full", function (assert) {
      //   2×1 grid, three AUTO slots — only two cells exist.
      //   ┌─────┬─────┐
      //   │ a₁  │ a₂  │   a₃ has nowhere to go → dropped
      //   └─────┴─────┘
      const slots = [
        { containerArgs: { grid: { column: "auto", row: "auto" } } },
        { containerArgs: { grid: { column: "auto", row: "auto" } } },
        { containerArgs: { grid: { column: "auto", row: "auto" } } },
      ];
      const occupied = computeOccupation(slots, 2, 1);
      assert.true(occupied.has("1,1"));
      assert.true(occupied.has("1,2"));
      assert.strictEqual(occupied.size, 2, "the third slot finds no free cell");
    });
  });

  module("computeZone — five-zone cell hit test", function () {
    //   ┌───────────────┐
    //   │      up       │
    //   │ l   center  r │   inner 60% = center, outer 20% bands = edges
    //   │     down      │
    //   └───────────────┘
    test("inner 60% is center", function (assert) {
      assert.strictEqual(computeZone(50, 50, 100, 100), "center");
    });

    test("each outer band maps to its edge", function (assert) {
      assert.strictEqual(computeZone(5, 50, 100, 100), "left");
      assert.strictEqual(computeZone(95, 50, 100, 100), "right");
      assert.strictEqual(computeZone(50, 5, 100, 100), "up");
      assert.strictEqual(computeZone(50, 95, 100, 100), "down");
    });

    test("corners use RELATIVE distance, not absolute pixels", function (assert) {
      //   Same cursor (4, 4) in two cells of opposite aspect ratio.
      //   Absolute px to each edge are identical (4 and 4), so only the
      //   PROPORTIONS decide — proving the metric is x/w vs y/h.
      //
      //   wide & short 400×40        tall & narrow 40×400
      //   ◆ near top-left            ◆ near top-left
      //   left band is proportionally  top band is proportionally
      //   nearer → "left"              nearer → "up"
      assert.strictEqual(computeZone(4, 4, 400, 40), "left");
      assert.strictEqual(computeZone(4, 4, 40, 400), "up");
    });
  });

  module("computeZoneCollapsed — three-zone Y hit test", function () {
    //   single-column (stacked) view — only up / center / down matter
    //   ┌─────────┐  y < 25%  → up
    //   │   up    │
    //   ├─────────┤  middle   → center
    //   │ center  │
    //   ├─────────┤  y > 75%  → down
    //   │  down   │
    //   └─────────┘
    test("maps the vertical thirds", function (assert) {
      assert.strictEqual(computeZoneCollapsed(10, 100), "up");
      assert.strictEqual(computeZoneCollapsed(50, 100), "center");
      assert.strictEqual(computeZoneCollapsed(90, 100), "down");
    });

    test("0.25 / 0.75 are the band edges (inclusive of center)", function (assert) {
      assert.strictEqual(computeZoneCollapsed(24, 100), "up");
      assert.strictEqual(computeZoneCollapsed(25, 100), "center");
      assert.strictEqual(computeZoneCollapsed(76, 100), "down");
    });

    test("zero-height element falls back to center", function (assert) {
      assert.strictEqual(computeZoneCollapsed(0, 0), "center");
    });
  });

  module("computeShiftPlan — cascade rearrangement", function () {
    const dims3x1 = { columns: 3, rows: 1 };

    test("A,B,C → C,A,B (drop C left of A; forward cascade)", function (assert) {
      //   before:  ┌───┬───┬───┐      drop C onto A's LEFT edge
      //            │ A │ B │ C │      A and B cascade RIGHT, C's old
      //            └───┴───┴───┘      cell absorbs the shift
      //   after:   │ C │ A │ B │
      const slots = [
        slot("A", "1", "1"),
        slot("B", "2", "1"),
        slot("C", "3", "1"),
      ];
      const plan = computeShiftPlan({
        slots,
        sourceKey: keyOf("C"),
        dropSlotKey: keyOf("A"),
        direction: "left",
        gridDims: dims3x1,
      });
      assert.deepEqual(plan.sourceLanding, { column: "1", row: "1" });
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("A")),
        { slotKey: keyOf("A"), column: "2", row: "1" }
      );
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("B")),
        { slotKey: keyOf("B"), column: "3", row: "1" }
      );
    });

    test("A,B,C → B,C,A (drop A right of C; backward-cascade fallback)", function (assert) {
      //   before:  ┌───┬───┬───┐      drop A past C's RIGHT edge; forward
      //            │ A │ B │ C │      cascade would overflow, so B and C
      //            └───┴───┴───┘      cascade LEFT into A's vacated cell
      //   after:   │ B │ C │ A │
      const slots = [
        slot("A", "1", "1"),
        slot("B", "2", "1"),
        slot("C", "3", "1"),
      ];
      const plan = computeShiftPlan({
        slots,
        sourceKey: keyOf("A"),
        dropSlotKey: keyOf("C"),
        direction: "right",
        gridDims: dims3x1,
      });
      assert.deepEqual(plan.sourceLanding, { column: "3", row: "1" });
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("B")),
        { slotKey: keyOf("B"), column: "1", row: "1" }
      );
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("C")),
        { slotKey: keyOf("C"), column: "2", row: "1" }
      );
    });

    test("clamps an over-the-edge landing and ripples into a vacancy", function (assert) {
      //   3×1, col 2 empty:  ┌───┬───┬───┐   palette drop past C's right
      //                      │ A │   │ C │   edge → landingCol 4 clamps to
      //                      └───┴───┴───┘   3; C cascades back into col 2
      //   after:             │ A │ C │ + │
      const slots = [slot("A", "1", "1"), slot("C", "3", "1")];
      const plan = computeShiftPlan({
        slots,
        sourceKey: null,
        dropSlotKey: keyOf("C"),
        direction: "right",
        gridDims: dims3x1,
      });
      assert.deepEqual(plan.sourceLanding, { column: "3", row: "1" });
      assert.deepEqual(plan.moves, [
        { slotKey: keyOf("C"), column: "2", row: "1" },
      ]);
    });

    test("empty-cell edge drop ripples the nearest neighbour (dropCell)", function (assert) {
      //   4×1, cols 1 & 4 empty:  ┌───┬───┬───┬───┐   drop at the RIGHT
      //                           │   │ B │ C │   │   edge of empty cell 1
      //                           └───┴───┴───┴───┘   → lands col 2, pushing
      //   after:                  │   │ + │ B │ C │   B and C right
      const slots = [slot("B", "2", "1"), slot("C", "3", "1")];
      const plan = computeShiftPlan({
        slots,
        sourceKey: null,
        dropSlotKey: null,
        dropCell: { column: 1, row: 1 },
        direction: "right",
        gridDims: { columns: 4, rows: 1 },
      });
      assert.deepEqual(plan.sourceLanding, { column: "2", row: "1" });
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("B")),
        { slotKey: keyOf("B"), column: "3", row: "1" }
      );
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("C")),
        { slotKey: keyOf("C"), column: "4", row: "1" }
      );
    });

    test("returns null when the cascade walks off a full grid", function (assert) {
      //   2×1 FULL:  ┌───┬───┐   nothing can absorb a new block on either
      //              │ A │ B │   side → no valid plan
      //              └───┴───┘
      const slots = [slot("A", "1", "1"), slot("B", "2", "1")];
      const plan = computeShiftPlan({
        slots,
        sourceKey: null,
        dropSlotKey: keyOf("B"),
        direction: "right",
        gridDims: { columns: 2, rows: 1 },
      });
      assert.strictEqual(plan, null);
    });

    test("cascades on the ROW axis (up direction)", function (assert) {
      //   1×3:  ┌───┐  drop C above A → A and B cascade DOWN
      //         │ A │
      //         │ B │  after:  │ C │
      //         │ C │          │ A │
      //         └───┘          │ B │
      const slots = [
        slot("A", "1", "1"),
        slot("B", "1", "2"),
        slot("C", "1", "3"),
      ];
      const plan = computeShiftPlan({
        slots,
        sourceKey: keyOf("C"),
        dropSlotKey: keyOf("A"),
        direction: "up",
        gridDims: { columns: 1, rows: 3 },
      });
      assert.deepEqual(plan.sourceLanding, { column: "1", row: "1" });
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("A")),
        { slotKey: keyOf("A"), column: "1", row: "2" }
      );
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("B")),
        { slotKey: keyOf("B"), column: "1", row: "3" }
      );
    });

    test("preserves a multi-column span as it shifts", function (assert) {
      //   4×1:  ┌───────┬───┬───┐   A spans cols 1–2; drop source on A's
      //         │   A   │ B │   │   LEFT → A keeps width 2 at cols 2–3,
      //         └───────┴───┴───┘   B slides to col 4
      //   after:│ + │   A   │ B │
      const slots = [slot("A", "1 / 3", "1"), slot("B", "3", "1")];
      const plan = computeShiftPlan({
        slots,
        sourceKey: null,
        dropSlotKey: keyOf("A"),
        direction: "left",
        gridDims: { columns: 4, rows: 1 },
      });
      assert.deepEqual(plan.sourceLanding, { column: "1", row: "1" });
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("A")),
        { slotKey: keyOf("A"), column: "2 / 4", row: "1" },
        "the 2-wide span is preserved"
      );
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("B")),
        { slotKey: keyOf("B"), column: "4", row: "1" }
      );
    });

    test("returns null for an unknown drop slot or no anchor at all", function (assert) {
      const slots = [slot("A", "1", "1")];
      assert.strictEqual(
        computeShiftPlan({
          slots,
          sourceKey: null,
          dropSlotKey: keyOf("ghost"),
          direction: "left",
          gridDims: dims3x1,
        }),
        null,
        "drop slot not in the grid"
      );
      assert.strictEqual(
        computeShiftPlan({
          slots,
          sourceKey: null,
          dropSlotKey: null,
          direction: "left",
          gridDims: dims3x1,
        }),
        null,
        "neither dropSlotKey nor dropCell"
      );
    });
  });

  module("spacesForFree", function () {
    test("returns every cell row-major as line shorthand", function (assert) {
      assert.deepEqual(spacesForFree(3, 2), [
        { column: "1", row: "1" },
        { column: "2", row: "1" },
        { column: "3", row: "1" },
        { column: "1", row: "2" },
        { column: "2", row: "2" },
        { column: "3", row: "2" },
      ]);
    });
  });

  module("reflowChildrenIntoSpaces", function () {
    test("places content into spaces in reading order", function (assert) {
      // Two blocks at (col2,row1) and (col1,row1) — reading order puts
      // the col1 block first, so it lands in the first space.
      const a = {
        block: "wf:heading",
        __stableKey: "a",
        containerArgs: { grid: { column: "2", row: "1" } },
      };
      const b = {
        block: "wf:paragraph",
        __stableKey: "b",
        containerArgs: { grid: { column: "1", row: "1" } },
      };
      const result = reflowChildrenIntoSpaces([a, b], spacesForFree(2, 1));
      assert.strictEqual(result.length, 2);
      assert.strictEqual(result[0].__stableKey, "b");
      assert.deepEqual(result[0].containerArgs.grid, { column: "1", row: "1" });
      assert.strictEqual(result[1].__stableKey, "a");
      assert.deepEqual(result[1].containerArgs.grid, { column: "2", row: "1" });
    });

    test("a child reflowed into a spanning space adopts the span", function (assert) {
      const a = {
        block: "wf:heading",
        __stableKey: "a",
        containerArgs: { grid: { column: "1", row: "1" } },
      };
      const spaces = [
        { column: "1 / 4", row: "1" },
        { column: "1", row: "2" },
      ];
      const result = reflowChildrenIntoSpaces([a], spaces);
      assert.strictEqual(result[0].containerArgs.grid.column, "1 / 4");
    });

    test("pads spanning leftover spaces with wf:cell, leaves single cells derived", function (assert) {
      // hero + 3: one spanning space, three single cells. With zero
      // content, only the spanning space materialises as an entry.
      const spaces = [
        { column: "1 / 4", row: "1" },
        { column: "1", row: "2" },
        { column: "2", row: "2" },
        { column: "3", row: "2" },
      ];
      const result = reflowChildrenIntoSpaces([], spaces);
      assert.strictEqual(result.length, 1);
      assert.strictEqual(result[0].block, "wf:cell");
      assert.strictEqual(result[0].containerArgs.grid.column, "1 / 4");
    });

    test("preserves align / justify on placed children", function (assert) {
      const a = {
        block: "wf:heading",
        __stableKey: "a",
        containerArgs: {
          grid: { column: "1", row: "1", align: "center", justify: "end" },
        },
      };
      const result = reflowChildrenIntoSpaces([a], [{ column: "2", row: "1" }]);
      assert.deepEqual(result[0].containerArgs.grid, {
        column: "2",
        row: "1",
        align: "center",
        justify: "end",
      });
    });

    test("refuses when content outnumbers spaces", function (assert) {
      const children = [
        {
          block: "wf:heading",
          __stableKey: "a",
          containerArgs: { grid: { column: "1", row: "1" } },
        },
        {
          block: "wf:paragraph",
          __stableKey: "b",
          containerArgs: { grid: { column: "2", row: "1" } },
        },
      ];
      assert.strictEqual(
        reflowChildrenIntoSpaces(children, [{ column: "1", row: "1" }]),
        null
      );
    });
  });

  module("syncContentToArrayOrder", function () {
    test("reassigns content to reading-order positions by array order", function (assert) {
      // Array order [A, B], but A sits at col2 and B at col1. Syncing
      // should give the first array child (A) the reading-first position
      // (col1) and B the next (col2).
      const children = [
        {
          block: "wf:heading",
          __stableKey: "A",
          containerArgs: { grid: { column: "2", row: "1" } },
        },
        {
          block: "wf:paragraph",
          __stableKey: "B",
          containerArgs: { grid: { column: "1", row: "1" } },
        },
      ];
      const result = syncContentToArrayOrder(children);
      assert.strictEqual(result[0].__stableKey, "A");
      assert.strictEqual(result[0].containerArgs.grid.column, "1");
      assert.strictEqual(result[1].__stableKey, "B");
      assert.strictEqual(result[1].containerArgs.grid.column, "2");
    });

    test("leaves wf:cell entries' rects untouched", function (assert) {
      const children = [
        {
          block: "wf:paragraph",
          __stableKey: "B",
          containerArgs: { grid: { column: "3", row: "1" } },
        },
        {
          block: "wf:cell",
          containerArgs: { grid: { column: "2", row: "1" } },
        },
        {
          block: "wf:heading",
          __stableKey: "A",
          containerArgs: { grid: { column: "1", row: "1" } },
        },
      ];
      const result = syncContentToArrayOrder(children);
      // Content positions in use are col1 and col3 (the wf:cell holds col2).
      // Array order is [B, A], so B takes the reading-first content slot.
      assert.strictEqual(result[0].__stableKey, "B");
      assert.strictEqual(result[0].containerArgs.grid.column, "1");
      assert.strictEqual(result[1].block, "wf:cell");
      assert.strictEqual(result[1].containerArgs.grid.column, "2");
      assert.strictEqual(result[2].__stableKey, "A");
      assert.strictEqual(result[2].containerArgs.grid.column, "3");
    });

    test("preserves a spanning content position", function (assert) {
      const children = [
        {
          block: "wf:paragraph",
          __stableKey: "B",
          containerArgs: { grid: { column: "4", row: "1" } },
        },
        {
          block: "wf:heading",
          __stableKey: "A",
          containerArgs: { grid: { column: "1 / 4", row: "1" } },
        },
      ];
      const result = syncContentToArrayOrder(children);
      // B is first in the array, so it takes the reading-first position —
      // the spanning "1 / 4" — and adopts the span.
      assert.strictEqual(result[0].__stableKey, "B");
      assert.strictEqual(result[0].containerArgs.grid.column, "1 / 4");
      assert.strictEqual(result[1].__stableKey, "A");
      assert.strictEqual(result[1].containerArgs.grid.column, "4");
    });

    test("no-op with fewer than two content children", function (assert) {
      const children = [
        {
          block: "wf:heading",
          __stableKey: "A",
          containerArgs: { grid: { column: "2", row: "1" } },
        },
        {
          block: "wf:cell",
          containerArgs: { grid: { column: "1", row: "1" } },
        },
      ];
      assert.strictEqual(syncContentToArrayOrder(children), children);
    });
  });
});
