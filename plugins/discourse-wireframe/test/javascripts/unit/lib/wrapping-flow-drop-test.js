import { module, test } from "qunit";
import { resolveLinearDrop } from "discourse/plugins/discourse-wireframe/discourse/lib/linear-drop";
import { resolveWrappingFlowDrop } from "discourse/plugins/discourse-wireframe/discourse/lib/wrapping-flow-drop";

// `resolveWrappingFlowDrop(rects, cursor, {mainAxis})` groups children into
// visual lines (bands) along the cross axis, picks the line under the cursor,
// then delegates within the line to the 1-D `resolveLinearDrop`. It returns the
// SAME shape as `resolveLinearDrop` (with GLOBAL boundary indices), plus an
// `indicator` for gaps in a genuinely wrapped container.
//
// `rect(left, right, top, bottom)` builds a bounding-box-shaped input.
function rect(left, right, top, bottom) {
  return { left, right, top, bottom };
}

module("Unit | Discourse Wireframe | lib:wrapping-flow-drop", function () {
  module("resolveWrappingFlowDrop", function () {
    test("empty container resolves to the start boundary", function (assert) {
      assert.deepEqual(resolveWrappingFlowDrop([], { x: 50, y: 50 }), {
        kind: "gap",
        gap: 0,
      });
      assert.deepEqual(resolveWrappingFlowDrop(undefined, { x: 50, y: 50 }), {
        kind: "gap",
        gap: 0,
      });
    });

    module(
      "single line (unwrapped) — collapses to resolveLinearDrop",
      function () {
        //   one row, three tiles, all sharing y [0..100]
        //   [0..100][100..200][200..300]
        const rects = [
          rect(0, 100, 0, 100),
          rect(100, 200, 0, 100),
          rect(200, 300, 0, 100),
        ];
        const segs = [
          { near: 0, far: 100 },
          { near: 100, far: 200 },
          { near: 200, far: 300 },
        ];

        test("gap results are byte-identical to the 1-D resolver (no indicator)", function (assert) {
          for (const x of [5, 90, 110, 190, 210, 295]) {
            assert.deepEqual(
              resolveWrappingFlowDrop(rects, { x, y: 50 }),
              resolveLinearDrop(segs, x),
              `x=${x} matches resolveLinearDrop`
            );
          }
        });

        test("middle thirds are byte-identical to the 1-D resolver", function (assert) {
          for (const [x, index] of [
            [50, 0],
            [150, 1],
            [250, 2],
          ]) {
            assert.deepEqual(resolveWrappingFlowDrop(rects, { x, y: 50 }), {
              kind: "middle",
              index,
            });
          }
        });
      }
    );

    module("two lines (wrapped) — 3 tiles, then 2", function () {
      //   line 1 (y 0..100):   [0..100][100..200][200..300]   indices 0,1,2
      //   line 2 (y 110..210): [0..100][100..200]             indices 3,4
      const rects = [
        rect(0, 100, 0, 100),
        rect(100, 200, 0, 100),
        rect(200, 300, 0, 100),
        rect(0, 100, 110, 210),
        rect(100, 200, 110, 210),
      ];

      test("interior gap in line 1 → global gap 1, tick confined to line 1", function (assert) {
        assert.deepEqual(resolveWrappingFlowDrop(rects, { x: 110, y: 50 }), {
          kind: "gap",
          gap: 1,
          indicator: { x: 100, top: 0, bottom: 100 },
        });
      });

      test("interior gap in line 2 → global gap 4, tick confined to line 2", function (assert) {
        assert.deepEqual(resolveWrappingFlowDrop(rects, { x: 100, y: 160 }), {
          kind: "gap",
          gap: 4,
          indicator: { x: 100, top: 110, bottom: 210 },
        });
      });

      test("start of line 2 → global gap 3 (leading edge tick)", function (assert) {
        assert.deepEqual(resolveWrappingFlowDrop(rects, { x: 5, y: 160 }), {
          kind: "gap",
          gap: 3,
          indicator: { x: 0, top: 110, bottom: 210 },
        });
      });

      test("end of line 2 → global gap 5 (trailing edge tick)", function (assert) {
        assert.deepEqual(resolveWrappingFlowDrop(rects, { x: 195, y: 160 }), {
          kind: "gap",
          gap: 5,
          indicator: { x: 200, top: 110, bottom: 210 },
        });
      });

      test("middle third of a line-2 tile → global index 3", function (assert) {
        assert.deepEqual(resolveWrappingFlowDrop(rects, { x: 50, y: 160 }), {
          kind: "middle",
          index: 3,
        });
      });

      test("global indices stay in DOM order (never reordered)", function (assert) {
        // A drop physically in line 2 must resolve to a line-2 DOM index, not a
        // same-column line-1 index — the failure the 1-D resolver has today.
        const result = resolveWrappingFlowDrop(rects, { x: 100, y: 160 });
        assert.true(result.gap >= 3, "targets line 2, not the line-1 x-band");
      });
    });

    module("band selection by cursor cross-axis", function () {
      const rects = [
        rect(0, 100, 0, 100), // line 1
        rect(0, 100, 110, 210), // line 2
      ];

      test("above all lines → nearest is line 1", function (assert) {
        assert.deepEqual(resolveWrappingFlowDrop(rects, { x: 50, y: -10 }), {
          kind: "middle",
          index: 0,
        });
      });

      test("below all lines → nearest is the last line", function (assert) {
        assert.deepEqual(resolveWrappingFlowDrop(rects, { x: 50, y: 300 }), {
          kind: "middle",
          index: 1,
        });
      });

      test("in the inter-line gutter → ties break to the later line", function (assert) {
        // y=105 is 5px from line 1's bottom (100) and 5px from line 2's top (110).
        assert.deepEqual(resolveWrappingFlowDrop(rects, { x: 50, y: 105 }), {
          kind: "middle",
          index: 1,
        });
      });
    });

    module("mixed-height children on one line stay ONE band", function () {
      // A tall tile next to a short one (align-items: flex-start): they overlap
      // in y, so they must not split into two bands (which would diverge from
      // the 1-D resolver). Order must not matter.
      const tallThenShort = [rect(0, 100, 0, 100), rect(100, 200, 0, 40)];
      const shortThenTall = [rect(0, 100, 0, 40), rect(100, 200, 0, 100)];

      test("tall-then-short → one band, matches 1-D (no indicator)", function (assert) {
        assert.deepEqual(
          resolveWrappingFlowDrop(tallThenShort, { x: 150, y: 20 }),
          { kind: "middle", index: 1 }
        );
      });

      test("short-then-tall → one band, matches 1-D (no indicator)", function (assert) {
        assert.deepEqual(
          resolveWrappingFlowDrop(shortThenTall, { x: 150, y: 20 }),
          { kind: "middle", index: 1 }
        );
      });
    });
  });
});
