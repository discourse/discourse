import { module, test } from "qunit";
import {
  parsePlacement,
  parseSlotPlacement,
  parseTrack,
} from "discourse/lib/blocks/-internals/grid-placement";

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
});
