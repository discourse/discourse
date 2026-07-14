import { module, test } from "qunit";
import { diffLayouts } from "discourse/plugins/discourse-wireframe/discourse/lib/outlet-change-summary";

// Builds a layout entry with the in-memory identity (`__stableKey`) the diff
// matches on. A string `block` keeps the serializer off the block registry.
function entry(key, { block = "text", args, children } = {}) {
  const e = { __stableKey: key, block };
  if (args) {
    e.args = args;
  }
  if (children) {
    e.children = children;
  }
  return e;
}

module("Unit | Discourse Wireframe | lib:outlet-change-summary", function () {
  test("identical layouts report no changes", function (assert) {
    const layout = [entry(1, { args: { a: 1 } }), entry(2)];
    const before = [entry(1, { args: { a: 1 } }), entry(2)];

    assert.deepEqual(diffLayouts(before, layout), {
      added: 0,
      removed: 0,
      moved: 0,
      edited: 0,
      reliable: true,
    });
  });

  test("a new block counts as added", function (assert) {
    const before = [entry(1)];
    const after = [entry(1), entry(2)];

    const summary = diffLayouts(before, after);
    assert.strictEqual(summary.added, 1);
    assert.strictEqual(summary.removed, 0);
  });

  test("a dropped block counts as removed", function (assert) {
    const before = [entry(1), entry(2)];
    const after = [entry(1)];

    const summary = diffLayouts(before, after);
    assert.strictEqual(summary.removed, 1);
    assert.strictEqual(summary.added, 0);
  });

  test("reordering siblings counts each as moved", function (assert) {
    const before = [entry(1), entry(2)];
    const after = [entry(2), entry(1)];

    const summary = diffLayouts(before, after);
    assert.strictEqual(summary.moved, 2);
    assert.strictEqual(summary.added, 0);
    assert.strictEqual(summary.removed, 0);
    assert.strictEqual(summary.edited, 0);
  });

  test("changing a block's args counts as edited", function (assert) {
    const before = [entry(1, { args: { a: 1 } })];
    const after = [entry(1, { args: { a: 2 } })];

    const summary = diffLayouts(before, after);
    assert.strictEqual(summary.edited, 1);
    assert.strictEqual(summary.moved, 0);
  });

  test("a nested child edit is counted, the unchanged parent is not", function (assert) {
    const before = [
      entry(1, { block: "layout", children: [entry(2, { args: { t: "x" } })] }),
    ];
    const after = [
      entry(1, { block: "layout", children: [entry(2, { args: { t: "y" } })] }),
    ];

    const summary = diffLayouts(before, after);
    assert.strictEqual(summary.edited, 1);
    assert.strictEqual(summary.added, 0);
    assert.strictEqual(summary.moved, 0);
  });

  test("a null baseline treats every block as added", function (assert) {
    const summary = diffLayouts(null, [entry(1), entry(2)]);
    assert.strictEqual(summary.added, 2);
    assert.true(summary.reliable);
  });

  test("two layouts with no shared identity fall back to a coarse edited count", function (assert) {
    const before = [entry(1), entry(2)];
    const after = [entry(10), entry(11)];

    const summary = diffLayouts(before, after);
    assert.false(summary.reliable);
    assert.strictEqual(summary.edited, 2);
    assert.strictEqual(summary.added, 0);
    assert.strictEqual(summary.removed, 0);
  });
});
