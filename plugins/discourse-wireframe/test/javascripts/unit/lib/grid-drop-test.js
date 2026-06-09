import { module, test } from "qunit";
import {
  decideGridDrop,
  GRID_DROP_ACTIONS,
  GRID_DROP_GESTURES,
  rectIsFree,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-drop";

// A grid cell holding a content block. `entryKey` keys an entry as
// `"${block}:${__stableKey}"`, so a cell named "a" resolves to the key
// "content:a". `column` / `row` accept CSS Grid shorthand ("2", "1 / 3",
// "auto").
function cell(key, column, row) {
  return {
    __stableKey: key,
    block: "content",
    containerArgs: { grid: { column, row } },
  };
}

function keyOf(k) {
  return `content:${k}`;
}

// An empty merged cell occupying a (possibly spanning) rect — the placeholder
// a drop consumes (REPLACE), inheriting its span. Keyed under the core block
// name so the decider's merged-cell carve-out recognises it.
function mergedCell(key, column, row) {
  return {
    __stableKey: key,
    block: "layout-merged-cell",
    containerArgs: { grid: { column, row } },
  };
}

function mergedKeyOf(k) {
  return `layout-merged-cell:${k}`;
}

// Convenience: an "existing block already in this grid" source.
function sameGrid(key) {
  return { kind: "existing", key: keyOf(key) };
}

// A block arriving from outside this grid (another grid / container).
function foreign(key) {
  return { kind: "existing", key: keyOf(key) };
}

// A freshly minted palette block (no existing entry).
const PALETTE = { kind: "new", key: null };

module("Unit | Discourse Wireframe | lib:grid-drop", function () {
  /* R1 — INTO a cell: fill / swap / replace, never shift, never grow. */
  module("INTO a cell (R1)", function () {
    test("empty cell → FILL, 1×1, no growth", function (assert) {
      // [A][_][B] drop X into the hole at column 2 → [A][X][B].
      const children = [cell("a", "1", "1"), cell("b", "3", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: PALETTE,
        drop: { gesture: GRID_DROP_GESTURES.INTO, cell: { column: 2, row: 1 } },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.FILL);
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      assert.deepEqual(decision.moves, []);
      assert.strictEqual(decision.swapWith, null);
      assert.deepEqual(decision.declared, { columns: 3, rows: 1 });
    });

    test("occupied cell, existing source → SWAP onto the occupant", function (assert) {
      // [A][B] drop A onto B → A takes B's cell, B takes A's cell.
      const children = [cell("a", "1", "1"), cell("b", "2", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 2, rows: 1 },
        source: sameGrid("a"),
        drop: { gesture: GRID_DROP_GESTURES.INTO, cell: { column: 2, row: 1 } },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.SWAP);
      assert.strictEqual(decision.swapWith, keyOf("b"));
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      assert.deepEqual(decision.declared, { columns: 2, rows: 1 });
    });

    test("occupied cell, Shift held → REPLACE the occupant", function (assert) {
      const children = [cell("a", "1", "1"), cell("b", "2", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 2, rows: 1 },
        source: foreign("x"),
        drop: {
          gesture: GRID_DROP_GESTURES.INTO,
          cell: { column: 2, row: 1 },
          shift: true,
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.REPLACE);
      assert.strictEqual(decision.swapWith, keyOf("b"));
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
    });

    test("occupied cell, palette source → NOOP (can't swap a new block)", function (assert) {
      const children = [cell("a", "1", "1"), cell("b", "2", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 2, rows: 1 },
        source: PALETTE,
        drop: { gesture: GRID_DROP_GESTURES.INTO, cell: { column: 2, row: 1 } },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.NOOP);
      assert.strictEqual(decision.placement, null);
      assert.strictEqual(decision.swapWith, null);
    });

    test("same-grid source dropped onto its OWN cell isn't its own occupant → FILL", function (assert) {
      // Dragging A onto the cell A already sits in: A is excluded from the
      // occupancy test, so the cell reads empty and A simply re-fills it.
      const children = [cell("a", "1", "1"), cell("b", "2", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 2, rows: 1 },
        source: sameGrid("a"),
        drop: { gesture: GRID_DROP_GESTURES.INTO, cell: { column: 1, row: 1 } },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.FILL);
      assert.deepEqual(decision.placement, { column: "1", row: "1" });
    });

    test("precise drop into a new row → FILL there, declared rows grow (R5)", function (assert) {
      const children = [cell("a", "1", "1"), cell("b", "2", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 2, rows: 1 },
        source: foreign("x"),
        drop: { gesture: GRID_DROP_GESTURES.INTO, cell: { column: 1, row: 2 } },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.FILL);
      assert.deepEqual(decision.placement, { column: "1", row: "2" });
      assert.deepEqual(decision.declared, { columns: 2, rows: 2 });
    });

    test("palette onto an empty merged cell → REPLACE, inheriting its span", function (assert) {
      // [A][ M…M ] — M spans columns 2–3. A palette block dropped into M
      // consumes M and inherits its full rect (not a 1×1 fill, not a NOOP).
      const children = [cell("a", "1", "1"), mergedCell("m", "2 / 4", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: PALETTE,
        drop: { gesture: GRID_DROP_GESTURES.INTO, cell: { column: 2, row: 1 } },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.REPLACE);
      assert.strictEqual(decision.swapWith, mergedKeyOf("m"));
      assert.deepEqual(decision.placement, { column: "2 / 4", row: "1" });
      // The merged cell already held the rect, so declared doesn't grow.
      assert.deepEqual(decision.declared, { columns: 3, rows: 1 });
    });

    test("existing block onto an empty merged cell → REPLACE, not SWAP", function (assert) {
      // A content occupant would SWAP; a merged cell is consumed instead, so
      // the moved block doesn't trade places with an empty placeholder.
      const children = [cell("a", "1", "1"), mergedCell("m", "2 / 4", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: sameGrid("a"),
        drop: { gesture: GRID_DROP_GESTURES.INTO, cell: { column: 2, row: 1 } },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.REPLACE);
      assert.strictEqual(decision.swapWith, mergedKeyOf("m"));
      assert.deepEqual(decision.placement, { column: "2 / 4", row: "1" });
    });

    test("merged-cell consume ignores the Shift flag", function (assert) {
      // Shift distinguishes SWAP from REPLACE for a content occupant; for a
      // merged cell the outcome is REPLACE-consume either way.
      const children = [cell("a", "1", "1"), mergedCell("m", "2 / 4", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: sameGrid("a"),
        drop: {
          gesture: GRID_DROP_GESTURES.INTO,
          cell: { column: 2, row: 1 },
          shift: false,
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.REPLACE);
      assert.strictEqual(decision.swapWith, mergedKeyOf("m"));
    });
  });

  /* R2 — BESIDE a cell: axis-pure cascade, absorbed by first hole, grow at edge. */
  module("BESIDE a cell (R2)", function () {
    test("beside a filled cell, hole absorbs → no growth", function (assert) {
      // [A][B][_][C] drop X before B → [A][X][B][C]; B lands on the hole.
      const children = [
        cell("a", "1", "1"),
        cell("b", "2", "1"),
        cell("c", "4", "1"),
      ];
      const decision = decideGridDrop({
        children,
        declared: { columns: 4, rows: 1 },
        source: PALETTE,
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 2, row: 1 },
          direction: "left",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      // B shifts 2 → 3 (the hole); C untouched at 4.
      assert.deepEqual(decision.moves, [
        { slotKey: keyOf("b"), column: "3", row: "1" },
      ]);
      assert.deepEqual(decision.declared, { columns: 4, rows: 1 });
    });

    test("beside a filled cell, row full → grow a column", function (assert) {
      // [A][B][C] drop X before B → [A][X][B][C]; columns 3 → 4.
      const children = [
        cell("a", "1", "1"),
        cell("b", "2", "1"),
        cell("c", "3", "1"),
      ];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: PALETTE,
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 2, row: 1 },
          direction: "left",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      assert.deepEqual(decision.declared, { columns: 4, rows: 1 });
      // B → 3, C → 4.
      assert.deepEqual(
        decision.moves.map((m) => [m.slotKey, m.column]),
        [
          [keyOf("b"), "3"],
          [keyOf("c"), "4"],
        ]
      );
    });

    test("beside a hole → the hole shifts (not absorbed), grow despite it", function (assert) {
      // [A][_][B] drop X before the hole at column 2 → [A][X][_][B]; cols 3 → 4.
      const children = [cell("a", "1", "1"), cell("b", "3", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: PALETTE,
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 2, row: 1 },
          direction: "left",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      // B shifts 3 → 4 (the drop-point hole is preserved at column 3).
      assert.deepEqual(decision.moves, [
        { slotKey: keyOf("b"), column: "4", row: "1" },
      ]);
      assert.deepEqual(decision.declared, { columns: 4, rows: 1 });
    });

    test("beside a hole, but a LATER hole absorbs → no growth", function (assert) {
      // [A][_][B][_] drop X before the first hole → [A][X][_][B]; B lands
      // on the trailing hole, columns unchanged.
      const children = [cell("a", "1", "1"), cell("b", "3", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 4, rows: 1 },
        source: PALETTE,
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 2, row: 1 },
          direction: "left",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      assert.deepEqual(decision.moves, [
        { slotKey: keyOf("b"), column: "4", row: "1" },
      ]);
      assert.deepEqual(decision.declared, { columns: 4, rows: 1 });
    });

    test("multi-row cascade is axis-pure: row-1 cascade grows a column, ignores row-2 holes", function (assert) {
      // Row1 [A][B][C] (full), Row2 [D][_][_]; drop X before B in row 1.
      const children = [
        cell("a", "1", "1"),
        cell("b", "2", "1"),
        cell("c", "3", "1"),
        cell("d", "1", "2"),
      ];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 2 },
        source: PALETTE,
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 2, row: 1 },
          direction: "left",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      // Grew a column rather than wrapping into row 2's holes.
      assert.deepEqual(decision.declared, { columns: 4, rows: 2 });
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      // D (row 2) is untouched.
      assert.false(decision.moves.some((m) => m.slotKey === keyOf("d")));
    });

    test("vertical cascade (down) grows a row when the column is full", function (assert) {
      // Column 1 full: [A]/[B] stacked; drop X below A → push B down, grow rows.
      const children = [cell("a", "1", "1"), cell("b", "1", "2")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 2, rows: 2 },
        source: PALETTE,
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 1, row: 1 },
          direction: "down",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      assert.deepEqual(decision.placement, { column: "1", row: "2" });
      assert.deepEqual(decision.declared, { columns: 2, rows: 3 });
      assert.deepEqual(decision.moves, [
        { slotKey: keyOf("b"), column: "1", row: "3" },
      ]);
    });

    test("same-grid source frees its own cell for the cascade to absorb", function (assert) {
      // [A][B][C] rotate: drop C before A → C lands at 1, A/B shift right
      // into C's vacated cell. No growth (C's cell absorbs the cascade).
      const children = [
        cell("a", "1", "1"),
        cell("b", "2", "1"),
        cell("c", "3", "1"),
      ];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: sameGrid("c"),
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 1, row: 1 },
          direction: "left",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      assert.deepEqual(decision.placement, { column: "1", row: "1" });
      // No growth: the row rotates within its existing 3 columns.
      assert.deepEqual(decision.declared, { columns: 3, rows: 1 });
    });

    test("drop before the leftmost cell, a spanning block ahead → grow, never land without making room", function (assert) {
      // [_][Important spanning 2-3] drop X before column 1. The source lands
      // at column 1; Important must shift right (keeping its 2-span) and the
      // grid grows to 4 columns: [X][_][Important 3-4]. The decider must NOT
      // settle for "drop X at col 1, leave Important put" — this is the
      // regression that shipped from the underlying cascade math, pinned here
      // at the single source of truth.
      const children = [cell("important", "2 / 4", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: foreign("x"),
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 1, row: 1 },
          direction: "left",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      assert.deepEqual(decision.placement, { column: "1", row: "1" });
      assert.deepEqual(decision.moves, [
        { slotKey: keyOf("important"), column: "3 / 5", row: "1" },
      ]);
      assert.deepEqual(decision.declared, { columns: 4, rows: 1 });
    });

    test("beside an empty edge with nothing to displace → lands at the line, no moves", function (assert) {
      // [A][_][_] drop X after the empty cell at column 3: nothing lies in
      // the cascade direction, so the source just lands at column 3 with no
      // displacement (a valid empty cascade, not a refusal).
      const children = [cell("a", "1", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: PALETTE,
        drop: {
          gesture: GRID_DROP_GESTURES.BESIDE,
          cell: { column: 3, row: 1 },
          direction: "right",
        },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.CASCADE);
      assert.deepEqual(decision.placement, { column: "3", row: "1" });
      assert.deepEqual(decision.moves, []);
      assert.deepEqual(decision.declared, { columns: 3, rows: 1 });
    });
  });

  /* R3 — GENERIC drop: next free cell in reading order; full grid adds a row. */
  module("GENERIC drop (R3)", function () {
    test("appends at the next free reading-order cell", function (assert) {
      const children = [cell("a", "1", "1"), cell("b", "2", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: PALETTE,
        drop: { gesture: GRID_DROP_GESTURES.GENERIC },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.APPEND);
      assert.deepEqual(decision.placement, { column: "3", row: "1" });
      assert.deepEqual(decision.declared, { columns: 3, rows: 1 });
    });

    test("full grid → first cell of a new row, declared rows grow", function (assert) {
      // Row1 [A][B][C] Row2 [D][E][F] (full), generic drop → Row3 first cell.
      const children = [
        cell("a", "1", "1"),
        cell("b", "2", "1"),
        cell("c", "3", "1"),
        cell("d", "1", "2"),
        cell("e", "2", "2"),
        cell("f", "3", "2"),
      ];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 2 },
        source: PALETTE,
        drop: { gesture: GRID_DROP_GESTURES.GENERIC },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.APPEND);
      assert.deepEqual(decision.placement, { column: "1", row: "3" });
      assert.deepEqual(decision.declared, { columns: 3, rows: 3 });
    });

    test("same-grid source doesn't occupy its own cell when finding the next free one", function (assert) {
      // [A][B][C] full; a GENERIC re-drop of B finds B's own cell free → B
      // re-appends at column 2 (its own spot), not a new row.
      const children = [
        cell("a", "1", "1"),
        cell("b", "2", "1"),
        cell("c", "3", "1"),
      ];
      const decision = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: sameGrid("b"),
        drop: { gesture: GRID_DROP_GESTURES.GENERIC },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.APPEND);
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      assert.deepEqual(decision.declared, { columns: 3, rows: 1 });
    });
  });

  /* Cross-cutting: foreign span discard, and effective-vs-declared sizing. */
  module("invariants", function () {
    test("a foreign span is discarded — the source always lands 1×1", function (assert) {
      // The source carries no placement here (the decision never reads the
      // source's span); the landing is always a single cell.
      const children = [cell("a", "1", "1")];
      const fill = decideGridDrop({
        children,
        declared: { columns: 3, rows: 1 },
        source: foreign("wide"),
        drop: { gesture: GRID_DROP_GESTURES.INTO, cell: { column: 2, row: 1 } },
      });
      assert.deepEqual(fill.placement, { column: "2", row: "1" });
      assert.false(
        fill.placement.column.includes("/"),
        "landing is a single line, not a span"
      );
    });

    test("declared reflects effective size when children already exceed declared", function (assert) {
      // Declared says 2×1 but a child sits at column 3 → effective is 3 wide.
      // A generic append lands at the next free effective cell and declared
      // is bumped to match usage (never shrinks).
      const children = [cell("a", "1", "1"), cell("b", "3", "1")];
      const decision = decideGridDrop({
        children,
        declared: { columns: 2, rows: 1 },
        source: PALETTE,
        drop: { gesture: GRID_DROP_GESTURES.GENERIC },
      });
      assert.strictEqual(decision.action, GRID_DROP_ACTIONS.APPEND);
      assert.deepEqual(decision.placement, { column: "2", row: "1" });
      assert.deepEqual(decision.declared, { columns: 3, rows: 1 });
    });
  });

  /* The occupancy primitive shared by the decider and the spanning insert. */
  module("rectIsFree (shared occupancy primitive)", function () {
    test("a blank region is free", function (assert) {
      // [A][_][_] — A at column 1; the columns 2–3 region is unoccupied.
      const kids = [cell("a", "1", "1")];
      assert.true(
        rectIsFree(kids, {
          column: { start: 2, end: 4 },
          row: { start: 1, end: 2 },
        })
      );
    });

    test("a region overlapping a placed entry is not free", function (assert) {
      // A spans columns 1–2; a rect touching column 2 overlaps it.
      const kids = [cell("a", "1 / 3", "1")];
      assert.false(
        rectIsFree(kids, {
          column: { start: 2, end: 4 },
          row: { start: 1, end: 2 },
        })
      );
    });

    test("auto-placed children never occupy", function (assert) {
      // An auto-placed child pins no column / row, so it covers nothing.
      const kids = [cell("a", "auto", "auto")];
      assert.true(
        rectIsFree(kids, {
          column: { start: 1, end: 2 },
          row: { start: 1, end: 2 },
        })
      );
    });

    test("excludeKey skips an entry's own placement", function (assert) {
      // The entry at the rect would block itself; excluding its key frees it,
      // matching how the decider credits a same-grid source's own cell.
      const kids = [cell("a", "1 / 3", "1")];
      const rect = {
        column: { start: 1, end: 3 },
        row: { start: 1, end: 2 },
      };
      assert.false(rectIsFree(kids, rect), "occupied without the exclusion");
      assert.true(
        rectIsFree(kids, rect, keyOf("a")),
        "free once the entry's own placement is excluded"
      );
    });
  });
});
