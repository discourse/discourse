import { module, test } from "qunit";
import {
  cellAt,
  cellsForFree,
  computeOccupation,
  computeShiftPlan,
  computeSpanResize,
  computeZone,
  computeZoneCollapsed,
  formatTrack,
  nextFreeCellInReadingOrder,
  reflowChildrenIntoCells,
  resizableDirections,
  resizeColumnFractions,
  syncContentToArrayOrder,
  unoccupiedCells,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";

// Builds an origin placement from CSS-grid-line numbers, matching the
// `{column: {start, end}, row: {start, end}}` shape `computeSpanResize` reads.
function rect(colStart, colEnd, rowStart, rowEnd) {
  return {
    column: { start: colStart, end: colEnd },
    row: { start: rowStart, end: rowEnd },
  };
}

// A grid cell fixture. `entryKey` (used internally by computeShiftPlan) keys
// an entry as `"${block}:${__stableKey}"`, so a cell named "k" resolves to
// the key "layout-merged-cell:k". `column` / `row` accept CSS Grid shorthand
// ("2", "1 / 3", "auto").
function slot(key, column, row) {
  return {
    __stableKey: key,
    block: "layout-merged-cell",
    containerArgs: { grid: { column, row } },
  };
}

function keyOf(k) {
  return `layout-merged-cell:${k}`;
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

  module("computeSpanResize — directional grid span", function () {
    test("east grows the trailing column edge to the pointer cell", function (assert) {
      const next = computeSpanResize({
        origin: rect(1, 2, 1, 2),
        cell: { column: 3, row: 1 },
        direction: "e",
        columns: 4,
        rows: 2,
      });
      assert.deepEqual(next, rect(1, 4, 1, 2), "end extends to cell 3 + 1");
    });

    test("west moves the leading column edge (origin extends left)", function (assert) {
      const next = computeSpanResize({
        origin: rect(3, 4, 1, 2),
        cell: { column: 1, row: 1 },
        direction: "w",
        columns: 4,
        rows: 2,
      });
      assert.deepEqual(next, rect(1, 4, 1, 2), "start moves to cell 1");
    });

    test("south grows the trailing row edge", function (assert) {
      const next = computeSpanResize({
        origin: rect(1, 2, 1, 2),
        cell: { column: 1, row: 3 },
        direction: "s",
        columns: 2,
        rows: 3,
      });
      assert.deepEqual(next, rect(1, 2, 1, 4), "row end extends to 3 + 1");
    });

    test("north moves the leading row edge up", function (assert) {
      const next = computeSpanResize({
        origin: rect(1, 2, 3, 4),
        cell: { column: 1, row: 1 },
        direction: "n",
        columns: 2,
        rows: 4,
      });
      assert.deepEqual(next, rect(1, 2, 1, 4), "row start moves to 1");
    });

    test("a corner grows both axes", function (assert) {
      const next = computeSpanResize({
        origin: rect(1, 2, 1, 2),
        cell: { column: 3, row: 2 },
        direction: "se",
        columns: 4,
        rows: 3,
      });
      assert.deepEqual(next, rect(1, 4, 1, 3), "both edges extend");
    });

    test("a growing edge clamps one track short of an occupied neighbour", function (assert) {
      // A neighbour fills column 3; an east span from column 1 must stop at the
      // edge before it (cols 1–2) so the rect never overlaps.
      const occupied = computeOccupation([slot("x", "3", "1")], 4, 1);
      const next = computeSpanResize({
        origin: rect(1, 2, 1, 2),
        cell: { column: 4, row: 1 },
        direction: "e",
        columns: 4,
        rows: 1,
        occupied,
      });
      assert.deepEqual(next, rect(1, 3, 1, 2), "end clamps before column 3");
    });

    test("an origin-moving edge clamps against an occupied cell behind it", function (assert) {
      // A neighbour fills row 1; a north span from row 3 stops at row 2.
      const occupied = computeOccupation([slot("x", "1", "1")], 1, 4);
      const next = computeSpanResize({
        origin: rect(1, 2, 3, 4),
        cell: { column: 1, row: 1 },
        direction: "n",
        columns: 1,
        rows: 4,
        occupied,
      });
      assert.deepEqual(next, rect(1, 2, 2, 4), "start clamps to row 2");
    });

    test("shrinking is never occupancy-clamped", function (assert) {
      // Dragging the east edge inward shrinks the span; an occupied cell
      // elsewhere must not interfere.
      const occupied = computeOccupation([slot("x", "4", "1")], 4, 1);
      const next = computeSpanResize({
        origin: rect(1, 4, 1, 2),
        cell: { column: 1, row: 1 },
        direction: "e",
        columns: 4,
        rows: 1,
        occupied,
      });
      assert.deepEqual(next, rect(1, 2, 1, 2), "shrinks to a 1×1 span");
    });

    test("respects grid bounds and a 1×1 minimum", function (assert) {
      const past = computeSpanResize({
        origin: rect(1, 2, 1, 2),
        cell: { column: 99, row: 99 },
        direction: "se",
        columns: 3,
        rows: 2,
      });
      assert.deepEqual(past, rect(1, 4, 1, 3), "clamps to the grid edges");

      const collapsed = computeSpanResize({
        origin: rect(2, 4, 1, 2),
        cell: { column: 1, row: 1 },
        direction: "w",
        columns: 4,
        rows: 2,
      });
      assert.deepEqual(
        collapsed,
        rect(1, 4, 1, 2),
        "start can reach line 1 but not past end - 1"
      );
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

  module("computeShiftPlan — growth (allowGrow)", function () {
    test("a hole in the row absorbs the cascade — no growth", function (assert) {
      // A at 1, hole at 2, B at 3. Drop left of A.
      const slots = [slot("A", "1", "1"), slot("B", "3", "1")];
      const plan = computeShiftPlan({
        slots,
        sourceKey: null,
        dropSlotKey: keyOf("A"),
        direction: "left",
        gridDims: { columns: 3, rows: 1 },
        allowGrow: true,
      });
      assert.deepEqual(plan.sourceLanding, { column: "1", row: "1" });
      assert.deepEqual(
        plan.moves,
        [{ slotKey: keyOf("A"), column: "2", row: "1" }],
        "A slides into the hole at column 2; B is untouched"
      );
    });

    test("a full row grows a column to absorb the cascade", function (assert) {
      // A, B, C fill a 3x1 grid. Drop left of A.
      const slots = [
        slot("A", "1", "1"),
        slot("B", "2", "1"),
        slot("C", "3", "1"),
      ];
      const plan = computeShiftPlan({
        slots,
        sourceKey: null,
        dropSlotKey: keyOf("A"),
        direction: "left",
        gridDims: { columns: 3, rows: 1 },
        allowGrow: true,
      });
      assert.deepEqual(plan.sourceLanding, { column: "1", row: "1" });
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("C")),
        { slotKey: keyOf("C"), column: "4", row: "1" },
        "C cascades into a freshly grown column 4"
      );
    });

    test("without allowGrow, a full row still returns null", function (assert) {
      const slots = [
        slot("A", "1", "1"),
        slot("B", "2", "1"),
        slot("C", "3", "1"),
      ];
      assert.strictEqual(
        computeShiftPlan({
          slots,
          sourceKey: null,
          dropSlotKey: keyOf("A"),
          direction: "left",
          gridDims: { columns: 3, rows: 1 },
        }),
        null,
        "the default (no growth) denies a cascade off the full row"
      );
    });

    test("drop before the leftmost cell grows instead of landing without making room", function (assert) {
      // hole at col 1, B spans cols 2–3 in a 3-col grid. Drop a foreign
      // block before col 1 (left edge). The forward cascade overflows at 3
      // columns, and scanning backward from col 1 finds nothing — a
      // zero-move "plan" that would drop the source at col 1 and leave B
      // untouched. That's wrong: B must shift right and the grid grows.
      const slots = [slot("B", "2 / 4", "1")];
      const plan = computeShiftPlan({
        slots,
        sourceKey: null,
        dropCell: { column: 1, row: 1 },
        direction: "left",
        gridDims: { columns: 3, rows: 1 },
        allowGrow: true,
      });
      assert.deepEqual(plan.sourceLanding, { column: "1", row: "1" });
      assert.deepEqual(
        plan.moves,
        [{ slotKey: keyOf("B"), column: "3 / 5", row: "1" }],
        "B shifts right one column (keeping its span) into a grown column 4"
      );
    });

    test("a full column grows a row (vertical axis mirror)", function (assert) {
      // A, B, C stacked in a 1x3 grid. Drop above A.
      const slots = [
        slot("A", "1", "1"),
        slot("B", "1", "2"),
        slot("C", "1", "3"),
      ];
      const plan = computeShiftPlan({
        slots,
        sourceKey: null,
        dropSlotKey: keyOf("A"),
        direction: "up",
        gridDims: { columns: 1, rows: 3 },
        allowGrow: true,
      });
      assert.deepEqual(plan.sourceLanding, { column: "1", row: "1" });
      assert.deepEqual(
        plan.moves.find((m) => m.slotKey === keyOf("C")),
        { slotKey: keyOf("C"), column: "1", row: "4" },
        "C cascades into a freshly grown row 4"
      );
    });
  });

  module("nextFreeCellInReadingOrder", function () {
    test("an empty grid yields the top-left cell", function (assert) {
      assert.deepEqual(
        nextFreeCellInReadingOrder([], { columns: 3, rows: 2 }),
        {
          column: 1,
          row: 1,
        }
      );
    });

    test("skips occupied cells in reading order", function (assert) {
      const children = [slot("A", "1", "1")];
      assert.deepEqual(
        nextFreeCellInReadingOrder(children, { columns: 3, rows: 2 }),
        { column: 2, row: 1 }
      );
    });

    test("advances down a single-column grid", function (assert) {
      const children = [slot("A", "1", "1")];
      assert.deepEqual(
        nextFreeCellInReadingOrder(children, { columns: 1, rows: 3 }),
        { column: 1, row: 2 }
      );
    });

    test("returns null when every cell is occupied", function (assert) {
      const children = [slot("A", "1", "1"), slot("B", "2", "1")];
      assert.strictEqual(
        nextFreeCellInReadingOrder(children, { columns: 2, rows: 1 }),
        null
      );
    });
  });

  module("cellsForFree", function () {
    test("returns every cell row-major as line shorthand", function (assert) {
      assert.deepEqual(cellsForFree(3, 2), [
        { column: "1", row: "1" },
        { column: "2", row: "1" },
        { column: "3", row: "1" },
        { column: "1", row: "2" },
        { column: "2", row: "2" },
        { column: "3", row: "2" },
      ]);
    });
  });

  module("reflowChildrenIntoCells", function () {
    test("places content into cells in reading order", function (assert) {
      // Two blocks at (col2,row1) and (col1,row1) — reading order puts
      // the col1 block first, so it lands in the first cell.
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
      const result = reflowChildrenIntoCells([a, b], cellsForFree(2, 1));
      assert.strictEqual(result.length, 2);
      assert.strictEqual(result[0].__stableKey, "b");
      assert.deepEqual(result[0].containerArgs.grid, { column: "1", row: "1" });
      assert.strictEqual(result[1].__stableKey, "a");
      assert.deepEqual(result[1].containerArgs.grid, { column: "2", row: "1" });
    });

    test("a child reflowed into a spanning cell adopts the span", function (assert) {
      const a = {
        block: "wf:heading",
        __stableKey: "a",
        containerArgs: { grid: { column: "1", row: "1" } },
      };
      const cells = [
        { column: "1 / 4", row: "1" },
        { column: "1", row: "2" },
      ];
      const result = reflowChildrenIntoCells([a], cells);
      assert.strictEqual(result[0].containerArgs.grid.column, "1 / 4");
    });

    test("pads spanning leftover cells with layout-merged-cell, leaves single cells derived", function (assert) {
      // hero + 3: one spanning cell, three single cells. With zero
      // content, only the spanning cell materialises as an entry.
      const cells = [
        { column: "1 / 4", row: "1" },
        { column: "1", row: "2" },
        { column: "2", row: "2" },
        { column: "3", row: "2" },
      ];
      const result = reflowChildrenIntoCells([], cells);
      assert.strictEqual(result.length, 1);
      assert.strictEqual(result[0].block, "layout-merged-cell");
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
      const result = reflowChildrenIntoCells([a], [{ column: "2", row: "1" }]);
      assert.deepEqual(result[0].containerArgs.grid, {
        column: "2",
        row: "1",
        align: "center",
        justify: "end",
      });
    });

    test("refuses when content outnumbers cells", function (assert) {
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
        reflowChildrenIntoCells(children, [{ column: "1", row: "1" }]),
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

    test("leaves layout-merged-cell entries' rects untouched", function (assert) {
      const children = [
        {
          block: "wf:paragraph",
          __stableKey: "B",
          containerArgs: { grid: { column: "3", row: "1" } },
        },
        {
          block: "layout-merged-cell",
          containerArgs: { grid: { column: "2", row: "1" } },
        },
        {
          block: "wf:heading",
          __stableKey: "A",
          containerArgs: { grid: { column: "1", row: "1" } },
        },
      ];
      const result = syncContentToArrayOrder(children);
      // Content positions in use are col1 and col3 (the layout-merged-cell holds col2).
      // Array order is [B, A], so B takes the reading-first content slot.
      assert.strictEqual(result[0].__stableKey, "B");
      assert.strictEqual(result[0].containerArgs.grid.column, "1");
      assert.strictEqual(result[1].block, "layout-merged-cell");
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
          block: "layout-merged-cell",
          containerArgs: { grid: { column: "1", row: "1" } },
        },
      ];
      assert.strictEqual(syncContentToArrayOrder(children), children);
    });
  });

  module("resizeColumnFractions", function () {
    test("a balanced grid stays [1, 1, …]", function (assert) {
      assert.deepEqual(resizeColumnFractions([100, 100], 0, 0), [1, 1]);
    });

    test("moves width between the two adjacent tracks", function (assert) {
      // 100/100, drag the line between col 1 and col 2 right by 20px.
      assert.deepEqual(resizeColumnFractions([100, 100], 0, 20), [1.2, 0.8]);
    });

    test("only the two adjacent tracks change", function (assert) {
      // 3 equal columns; dragging line 1↔2 leaves column 3 at 1fr.
      assert.deepEqual(
        resizeColumnFractions([100, 100, 100], 0, 50),
        [1.5, 0.5, 1]
      );
    });

    test("clamps so neither track drops below minPx", function (assert) {
      // Drag far past the right track's min (24px): left grows to 176,
      // right pinned at 24 → 1.76 / 0.24 ratios, snapped to 0.05.
      assert.deepEqual(
        resizeColumnFractions([100, 100], 0, 999, { minPx: 24 }),
        [1.75, 0.25]
      );
    });

    test("an out-of-range line returns a balanced grid", function (assert) {
      // Line index past the last interior line — guard, never happens
      // in practice.
      assert.deepEqual(resizeColumnFractions([100, 100], 1, 10), [1, 1]);
    });

    test("proportional grows the left track against all columns to its right", function (assert) {
      // 3 equal columns; grow col 1 by 60px. Split-pane would take it all
      // from col 2 ([1.6, 0.4, 1]); proportional spreads it across cols 2
      // AND 3 (each loses 30px), leaving them equal.
      assert.deepEqual(
        resizeColumnFractions([100, 100, 100], 0, 60, { proportional: true }),
        [1.6, 0.7, 0.7]
      );
    });

    test("proportional leaves columns to the LEFT of the line untouched", function (assert) {
      // 3 equal columns; drag line 2↔3 right by 60. Col 1 (left of the
      // line) stays 1fr; col 2 grows, col 3 absorbs it.
      const result = resizeColumnFractions([100, 100, 100], 1, 60, {
        proportional: true,
      });
      assert.strictEqual(result[0], 1, "left column unchanged");
      assert.true(result[1] > 1, "dragged column grew");
      assert.true(result[2] < 1, "right column shrank");
    });

    test("proportional on a two-column grid equals split-pane", function (assert) {
      assert.deepEqual(
        resizeColumnFractions([100, 100], 0, 20, { proportional: true }),
        resizeColumnFractions([100, 100], 0, 20)
      );
    });

    test("proportional clamps the right side at minPx", function (assert) {
      // Grow col 1 of a 3-col grid past what the right side can give:
      // cols 2 and 3 bottom out at 24px each (Δ clamped to 152), so the
      // widths become 252 / 24 / 24 → 2.5 / 0.25 / 0.25 after normalising.
      assert.deepEqual(
        resizeColumnFractions([100, 100, 100], 0, 999, {
          minPx: 24,
          proportional: true,
        }),
        [2.5, 0.25, 0.25]
      );
    });
  });

  module("resizableDirections", function () {
    test("a corner 1×1 grows only inward", function (assert) {
      // Top-left 1×1 in a 3×2 grid, nothing else placed: east + south + corner.
      assert.deepEqual(
        resizableDirections({
          origin: rect(1, 2, 1, 2),
          columns: 3,
          rows: 2,
          occupied: new Set(),
        }).sort(),
        ["e", "s", "se"].sort()
      );
    });

    test("edge cells omit out-of-bounds directions", function (assert) {
      // Bottom-right 1×1 of a 3×2 grid: only west + north (+ corner) are inward.
      assert.deepEqual(
        resizableDirections({
          origin: rect(3, 4, 2, 3),
          columns: 3,
          rows: 2,
          occupied: new Set(),
        }).sort(),
        ["n", "w", "nw"].sort()
      );
    });

    test("a multi-cell block mid-grid can grow and shrink on both axes", function (assert) {
      // 2×2 block at cols 1–2, rows 1–2 in a 4×4 grid: all eight handles.
      assert.deepEqual(
        resizableDirections({
          origin: rect(1, 3, 1, 3),
          columns: 4,
          rows: 4,
          occupied: new Set(),
        }).sort(),
        ["e", "n", "ne", "nw", "s", "se", "sw", "w"].sort()
      );
    });

    test("a 1×1 hemmed in on all sides has no handles", function (assert) {
      // Centre cell of a 3×3 grid with every orthogonal neighbour occupied.
      const occupied = computeOccupation(
        [
          slot("n", "2", "1"),
          slot("s", "2", "3"),
          slot("w", "1", "2"),
          slot("e", "3", "2"),
        ],
        3,
        3
      );
      assert.deepEqual(
        resizableDirections({
          origin: rect(2, 3, 2, 3),
          columns: 3,
          rows: 3,
          occupied,
        }),
        []
      );
    });

    test("a blocked neighbour hides growth but a span keeps the shrink handle", function (assert) {
      // 2-wide block at cols 1–2, row 1 of a 3×1 grid with col 3 occupied:
      // east can't grow (col 3 taken) but can shrink (span 2), so "e" stays;
      // west is at the boundary but the span keeps "w" (shrink). One row, span
      // one vertically, so n/s and the corners are out.
      const occupied = computeOccupation([slot("x", "3", "1")], 3, 1);
      assert.deepEqual(
        resizableDirections({
          origin: rect(1, 3, 1, 2),
          columns: 3,
          rows: 1,
          occupied,
        }).sort(),
        ["e", "w"].sort()
      );
    });

    test("a blocked 1×1 neighbour with no span drops that direction", function (assert) {
      // 1×1 at col 1, row 1 of a 3×1 grid with col 2 occupied: east is blocked
      // and there's no span to shrink, so no handle survives.
      const occupied = computeOccupation([slot("x", "2", "1")], 3, 1);
      assert.deepEqual(
        resizableDirections({
          origin: rect(1, 2, 1, 2),
          columns: 3,
          rows: 1,
          occupied,
        }),
        []
      );
    });
  });
});
