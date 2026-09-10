import { module, test } from "qunit";
import { matchGridTemplate } from "discourse/plugins/discourse-wireframe/discourse/lib/grid/grid-templates";

function cell(column, row) {
  return {
    block: "layout-merged-cell",
    containerArgs: { grid: { column, row } },
  };
}

function content(column, row) {
  return { block: "wf:heading", containerArgs: { grid: { column, row } } };
}

module(
  "Unit | Discourse Wireframe | lib:grid-templates | matchGridTemplate",
  function () {
    test("matches a hero-plus-three shape (all empty)", function (assert) {
      // The hero rect is a multi-cell `layout-merged-cell` entry; a/b/c are derived
      // single empties. Together they reconstruct the preset's shape.
      const children = [cell("1 / 4", "1")];
      const match = matchGridTemplate(children, 3, 2);
      assert.strictEqual(match?.id, "hero-plus-three");
    });

    test("matches a partially-filled hero-plus-three", function (assert) {
      // Hero filled with content, the bottom row left empty (derived).
      const children = [content("1 / 4", "1")];
      const match = matchGridTemplate(children, 3, 2);
      assert.strictEqual(match?.id, "hero-plus-three");
    });

    test("a uniform grid reads as Free (no match)", function (assert) {
      // A plain 2×2 grid of single cells is geometrically free mode —
      // no spanning preset claims it.
      assert.strictEqual(matchGridTemplate([], 2, 2), null);
    });

    test("dimensions must match the preset", function (assert) {
      // The hero rect alone, but in a 4-column grid, is not hero-plus-three.
      assert.strictEqual(matchGridTemplate([cell("1 / 4", "1")], 4, 2), null);
    });
  }
);
