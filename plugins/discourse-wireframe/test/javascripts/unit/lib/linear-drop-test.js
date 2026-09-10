import { module, test } from "qunit";
import { resolveLinearDrop } from "discourse/plugins/discourse-wireframe/discourse/lib/linear-drop";

// `resolveLinearDrop(segments, cursor)` is pure axis geometry: each segment
// is a child's `{ near, far }` extent along the active axis, `cursor` is a
// single coordinate. It returns either a BOUNDARY (`{ kind: "gap", gap }`,
// where `gap` is a boundary index in `[0 .. N]`) or the MIDDLE third of a
// child (`{ kind: "middle", index }`).
//
// The headline behaviour is the COLLAPSE: the old "after A" and "before B"
// zones map to the same boundary index, so a single "between A and B" zone
// replaces the two competing ones.
module("Unit | Discourse Wireframe | lib:linear-drop", function () {
  module("resolveLinearDrop", function () {
    //   (no children)
    //   ┌───────────────┐
    //   │     empty     │  ◆ cursor anywhere
    //   └───────────────┘
    //   → gap 0 (the only landing is "into" the container)
    test("empty container resolves to the start boundary", function (assert) {
      assert.deepEqual(resolveLinearDrop([], 50), { kind: "gap", gap: 0 });
      assert.deepEqual(resolveLinearDrop(undefined, 50), {
        kind: "gap",
        gap: 0,
      });
    });

    module("single child [0..100]", function () {
      //   0        100
      //   ├────┬────┬────┤
      //   │ b  │ m  │ a  │      b = first third, m = middle, a = last third
      //   gap0      gap1
      const seg = [{ near: 0, far: 100 }];

      test("first third → boundary before (gap 0)", function (assert) {
        //   ◆ at 10 (first third)
        assert.deepEqual(resolveLinearDrop(seg, 10), { kind: "gap", gap: 0 });
      });

      test("middle third → middle of child 0", function (assert) {
        //   ◆ at 50 (middle third)
        assert.deepEqual(resolveLinearDrop(seg, 50), {
          kind: "middle",
          index: 0,
        });
      });

      test("last third → boundary after (gap 1)", function (assert) {
        //   ◆ at 90 (last third)
        assert.deepEqual(resolveLinearDrop(seg, 90), { kind: "gap", gap: 1 });
      });

      test("before the child → gap 0", function (assert) {
        //   ◆ at -5 (off the near edge)
        assert.deepEqual(resolveLinearDrop(seg, -5), { kind: "gap", gap: 0 });
      });

      test("past the child → gap 1", function (assert) {
        //   ◆ at 150 (off the far edge)
        assert.deepEqual(resolveLinearDrop(seg, 150), { kind: "gap", gap: 1 });
      });
    });

    module("two children, touching [0..100][100..200]", function () {
      //          A                 B
      //   0      66  100    133    200
      //   ├───┬───┬───┼───┬───┬───┤
      //   │ b │ m │ a │ b │ m │ a │
      //  gap0   idx0 gap1   idx1  gap2
      const segs = [
        { near: 0, far: 100 },
        { near: 100, far: 200 },
      ];

      test("THE COLLAPSE: last-third-A, the A|B seam, and first-third-B all resolve to gap 1", function (assert) {
        //   …│ A …a │ ◆seam │ b… B │…
        //          90      100      110
        //   every one of these is the single "between A and B" boundary
        assert.deepEqual(
          resolveLinearDrop(segs, 90),
          { kind: "gap", gap: 1 },
          "last third of A → gap 1"
        );
        assert.deepEqual(
          resolveLinearDrop(segs, 100),
          { kind: "gap", gap: 1 },
          "exact A|B seam → gap 1"
        );
        assert.deepEqual(
          resolveLinearDrop(segs, 110),
          { kind: "gap", gap: 1 },
          "first third of B → gap 1"
        );
      });

      test("middles stay distinct", function (assert) {
        assert.deepEqual(resolveLinearDrop(segs, 50), {
          kind: "middle",
          index: 0,
        });
        assert.deepEqual(resolveLinearDrop(segs, 150), {
          kind: "middle",
          index: 1,
        });
      });

      test("container edges → gap 0 (start) and gap 2 (end)", function (assert) {
        //   ◆-5         ◆190        ◆205
        //   gap0        gap2        gap2
        assert.deepEqual(resolveLinearDrop(segs, -5), { kind: "gap", gap: 0 });
        assert.deepEqual(resolveLinearDrop(segs, 10), { kind: "gap", gap: 0 });
        assert.deepEqual(resolveLinearDrop(segs, 190), { kind: "gap", gap: 2 });
        assert.deepEqual(resolveLinearDrop(segs, 205), { kind: "gap", gap: 2 });
      });
    });

    module("two children with a gap [0..90][110..200]", function () {
      //          A          ⟂gap⟂          B
      //   0     60  90      110    143    200
      //   ├──┬──┬──┤  · · · ├──┬──┬──┤
      //  gap0   idx0 gap1(the whole seam) idx1  gap2
      const segs = [
        { near: 0, far: 90 },
        { near: 110, far: 200 },
      ];

      test("the empty seam between A and B is one boundary (gap 1)", function (assert) {
        //   ◆80 (last third A) · ◆100 (dead gap) · ◆120 (first third B)
        assert.deepEqual(resolveLinearDrop(segs, 80), { kind: "gap", gap: 1 });
        assert.deepEqual(resolveLinearDrop(segs, 100), { kind: "gap", gap: 1 });
        assert.deepEqual(resolveLinearDrop(segs, 120), { kind: "gap", gap: 1 });
      });
    });

    module("three children [0..100][100..200][200..300]", function () {
      //     A         B         C
      //   gap0  gap1     gap2     gap3
      //   every INTERIOR seam (A|B, B|C) collapses to a single boundary
      const segs = [
        { near: 0, far: 100 },
        { near: 100, far: 200 },
        { near: 200, far: 300 },
      ];

      test("interior boundaries collapse (gap 1 between A|B, gap 2 between B|C)", function (assert) {
        assert.deepEqual(resolveLinearDrop(segs, 90), { kind: "gap", gap: 1 });
        assert.deepEqual(resolveLinearDrop(segs, 110), { kind: "gap", gap: 1 });
        assert.deepEqual(resolveLinearDrop(segs, 190), { kind: "gap", gap: 2 });
        assert.deepEqual(resolveLinearDrop(segs, 210), { kind: "gap", gap: 2 });
      });

      test("start and end boundaries are gap 0 and gap 3", function (assert) {
        assert.deepEqual(resolveLinearDrop(segs, 5), { kind: "gap", gap: 0 });
        assert.deepEqual(resolveLinearDrop(segs, 295), { kind: "gap", gap: 3 });
      });

      test("each middle third maps to its own child index", function (assert) {
        assert.deepEqual(resolveLinearDrop(segs, 50), {
          kind: "middle",
          index: 0,
        });
        assert.deepEqual(resolveLinearDrop(segs, 150), {
          kind: "middle",
          index: 1,
        });
        assert.deepEqual(resolveLinearDrop(segs, 250), {
          kind: "middle",
          index: 2,
        });
      });
    });

    test("is axis-agnostic — the same numbers resolve identically whether they came from x or y", function (assert) {
      //   The caller picks the axis (clientX for a row, clientY for a stack)
      //   and projects rects to `{ near, far }`; the helper only sees numbers.
      const segs = [
        { near: 0, far: 100 },
        { near: 100, far: 200 },
      ];
      const fromX = resolveLinearDrop(segs, 110);
      const fromY = resolveLinearDrop(segs, 110);
      assert.deepEqual(fromX, fromY, "no hidden axis dependence");
      assert.deepEqual(fromX, { kind: "gap", gap: 1 });
    });
  });
});
