import { module, test } from "qunit";
import {
  childPath,
  childrenOf,
  combinatorOf,
  insertGroup,
  insertLeaf,
  isGroup,
  isLeaf,
  newEmptyGroup,
  removeAt,
  setCombinator,
  updateLeaf,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree-ops";

module("Unit | Discourse Wireframe | lib:condition-tree-ops", function () {
  test("isGroup discriminates arrays / any / not from leaves", function (assert) {
    assert.true(isGroup([]));
    assert.true(isGroup({ any: [] }));
    assert.true(isGroup({ not: { type: "user" } }));
    assert.false(isGroup({ type: "user" }));
    assert.false(isGroup(null));
  });

  test("isLeaf only matches leaf shape", function (assert) {
    assert.true(isLeaf({ type: "user" }));
    assert.false(isLeaf([]));
    assert.false(isLeaf({ any: [] }));
    assert.false(isLeaf(null));
  });

  test("combinatorOf returns the correct combinator", function (assert) {
    assert.strictEqual(combinatorOf([]), "and");
    assert.strictEqual(combinatorOf({ any: [] }), "or");
    assert.strictEqual(combinatorOf({ not: { type: "user" } }), "not");
    assert.strictEqual(combinatorOf({ type: "user" }), null);
  });

  test("childrenOf normalises single-child NOT into a 1-array", function (assert) {
    assert.deepEqual(childrenOf([{ type: "a" }, { type: "b" }]), [
      { type: "a" },
      { type: "b" },
    ]);
    assert.deepEqual(childrenOf({ any: [{ type: "a" }] }), [{ type: "a" }]);
    assert.deepEqual(childrenOf({ not: { type: "a" } }), [{ type: "a" }]);
    assert.deepEqual(childrenOf({ not: [{ type: "a" }, { type: "b" }] }), [
      { type: "a" },
      { type: "b" },
    ]);
  });

  test("childPath builds the right path per combinator", function (assert) {
    assert.deepEqual(childPath([], [{ type: "a" }], 0), [0]);
    assert.deepEqual(childPath([], { any: [{ type: "a" }] }, 0), ["any", 0]);
    assert.deepEqual(childPath([], { not: { type: "a" } }, 0), ["not"]);
    assert.deepEqual(childPath([], { not: [{ type: "a" }] }, 0), ["not", 0]);
  });

  test("insertLeaf appends into an AND root", function (assert) {
    const tree = [{ type: "a" }];
    const next = insertLeaf(tree, [], "viewport");
    assert.deepEqual(next, [{ type: "a" }, { type: "viewport" }]);
  });

  test("insertLeaf appends into an OR root via the any list", function (assert) {
    const tree = { any: [{ type: "a" }] };
    const next = insertLeaf(tree, [], "viewport");
    assert.deepEqual(next, { any: [{ type: "a" }, { type: "viewport" }] });
  });

  test("insertLeaf appended into NOT promotes single-child to multi-child", function (assert) {
    const tree = { not: { type: "a" } };
    const next = insertLeaf(tree, [], "viewport");
    assert.deepEqual(next, { not: [{ type: "a" }, { type: "viewport" }] });
  });

  test("insertGroup appends a fresh group", function (assert) {
    const tree = [{ type: "a" }];
    const next = insertGroup(tree, [], "or");
    assert.deepEqual(next, [{ type: "a" }, { any: [] }]);
  });

  test("removeAt deletes the node at path", function (assert) {
    const tree = [{ type: "a" }, { type: "b" }];
    const next = removeAt(tree, [0]);
    assert.deepEqual(next, [{ type: "b" }]);
  });

  test("removeAt returns null when the path is empty (clear all)", function (assert) {
    const next = removeAt([{ type: "a" }], []);
    assert.strictEqual(next, null);
  });

  test("setCombinator converts an AND root to an OR root, preserving children", function (assert) {
    const tree = [{ type: "a" }, { type: "b" }];
    const next = setCombinator(tree, [], "or");
    assert.deepEqual(next, { any: [{ type: "a" }, { type: "b" }] });
  });

  test("setCombinator converts a leaf root to a single-child NOT", function (assert) {
    const tree = { type: "user", admin: true };
    const next = setCombinator(tree, [], "not");
    assert.deepEqual(next, { not: { type: "user", admin: true } });
  });

  test("setCombinator on a nested group preserves children", function (assert) {
    const tree = [{ type: "a" }, [{ type: "b" }, { type: "c" }]];
    const next = setCombinator(tree, [1], "or");
    assert.deepEqual(next, [
      { type: "a" },
      { any: [{ type: "b" }, { type: "c" }] },
    ]);
  });

  test("updateLeaf replaces the leaf at path", function (assert) {
    const tree = [{ type: "user" }, { type: "viewport" }];
    const next = updateLeaf(tree, [0], { type: "user", admin: true });
    assert.deepEqual(next, [
      { type: "user", admin: true },
      { type: "viewport" },
    ]);
  });

  test("newEmptyGroup seeds NOT with a default leaf", function (assert) {
    assert.deepEqual(newEmptyGroup("and"), []);
    assert.deepEqual(newEmptyGroup("or"), { any: [] });
    assert.deepEqual(newEmptyGroup("not"), { not: { type: "user" } });
  });
});
