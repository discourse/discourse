import { module, test } from "qunit";
import {
  cellAt,
  computeOccupation,
  formatTrack,
  parseSlotPlacement,
  parseTrack,
  unoccupiedCells,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";

module("Unit | Discourse Wireframe | lib:grid-math", function () {
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
});
