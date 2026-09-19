import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import DAG, { type DAGPosition } from "discourse/lib/dag";

function resolveKeys(dag: DAG) {
  return dag.resolve().map((entry) => entry.key);
}

/**
 * Options matching the surfaces that point their default position at a
 * single key, which gives that key an in-degree equal to the item count.
 */
function hubOptions() {
  return { defaultPosition: { before: "hub" }, throwErrorOnCycle: false };
}

/** Three items before the hub plus one after it, in registration order. */
function addHubGroup(dag: DAG) {
  dag.add("first", 1, { before: ["hub"] });
  dag.add("second", 2, { before: ["hub"] });
  dag.add("third", 3, { before: ["hub"] });
  dag.add("hub", 4, {});
  dag.add("trailing", 5, { after: ["hub"] });
}

module("Unit | Lib | DAG", function (hooks) {
  setupTest(hooks);

  /* Core API */

  test("DAG.from creates a DAG instance from the provided entries", function (assert) {
    const dag = DAG.from([
      ["key1", "value1", { after: "key2" }],
      ["key2", "value2", { before: "key3" }],
      ["key3", "value3", { before: "key1" }],
    ]);

    assert.true(dag.has("key1"));
    assert.true(dag.has("key2"));
    assert.true(dag.has("key3"));

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key2", "key3", "key1"]);
  });

  test("adds items to the map", function (assert) {
    const dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    assert.true(dag.has("key1"));
    assert.true(dag.has("key2"));
    assert.true(dag.has("key3"));

    assert.true(
      dag.add("key4", "value4"),
      "adding an item returns true when the item is added"
    );
    assert.true(dag.has("key4"));

    assert.false(
      dag.add("key1", "value1"),
      "adding an item returns false when the item already exists"
    );
  });

  test("does not throw an error when throwErrorOnCycle is false when adding an item creates a cycle", function (assert) {
    const dag = new DAG({
      throwErrorOnCycle: false,
      defaultPosition: { before: "key3" },
    });

    dag.add("key1", "value1", { after: "key2" });
    dag.add("key2", "value2", { after: "key3" });

    // This would normally cause a cycle if throwErrorOnCycle was true
    dag.add("key3", "value3", { after: "key1" });

    assert.true(dag.has("key1"));
    assert.true(dag.has("key2"));
    assert.true(dag.has("key3"));

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    // Check that the default position was used to avoid the cycle
    assert.deepEqual(keys, ["key3", "key2", "key1"]);
  });

  test("calls the method specified for onAddItem callback when an item is added", function (assert) {
    let called = 0;

    const dag = new DAG({
      onAddItem: () => {
        called++;
      },
    });
    dag.add("key1", "value1");
    assert.strictEqual(called, 1, "the callback was called");

    // it doesn't call the callback when the item already exists
    dag.add("key1", "value1");
    assert.strictEqual(called, 1, "the callback was not called");
  });

  test("removes an item from the map", function (assert) {
    const dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    let removed = dag.delete("key2");

    assert.true(dag.has("key1"));
    assert.false(dag.has("key2"));
    assert.true(dag.has("key3"));

    assert.true(removed, "delete returns true when the item is removed");

    removed = dag.delete("key2");
    assert.false(removed, "delete returns false when the item doesn't exist");
  });

  test("calls the method specified for onDeleteItem callback when an item is removed", function (assert) {
    let called = 0;

    const dag = new DAG({
      onDeleteItem: () => {
        called++;
      },
    });
    dag.add("key1", "value1");
    dag.delete("key1");
    assert.strictEqual(called, 1, "the callback was called");

    // it doesn't call the callback when the item doesn't exist
    dag.delete("key1");
    assert.strictEqual(called, 1, "the callback was not called");
  });

  test("replaces the value from an item in the map", function (assert) {
    const dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    let replaced = dag.replace("key2", "replaced-value2");

    assert.deepEqual(
      dag.resolve().map((entry) => entry.value),
      ["value1", "replaced-value2", "value3"],
      "replace allows simply replacing the value"
    );
    assert.true(replaced, "replace returns true when the item is replaced");

    dag.replace("key2", "replaced-value2-again", { before: "key1" });

    assert.deepEqual(
      dag.resolve().map((entry) => entry.value),
      ["replaced-value2-again", "value1", "value3"],
      "replace also allows changing the position"
    );

    replaced = dag.replace("key4", "replaced-value4");
    assert.false(replaced, "replace returns false when the item doesn't exist");
  });

  test("calls the method specified for onReplaceItem callback when an item is replaced", function (assert) {
    let called = 0;

    const dag = new DAG({
      onReplaceItem: () => {
        called++;
      },
    });
    dag.add("key1", "value1");
    dag.replace("key1", "replaced-value1");
    assert.strictEqual(called, 1, "the callback was called");

    dag.replace("key2", "replaced-value2");
    assert.strictEqual(called, 1, "the callback was not called");
  });

  test("repositions an item in the map", function (assert) {
    const dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    let repositioned = dag.reposition("key3", { before: "key1" });
    assert.true(
      repositioned,
      "reposition returns true when the item is repositioned"
    );

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key3", "key1", "key2"]);

    repositioned = dag.reposition("key4", { before: "key1" });
    assert.false(
      repositioned,
      "reposition returns false when the item doesn't exist"
    );
  });

  test("calls the method specified for onRepositionItem callback when an item is repositioned", function (assert) {
    let called = 0;

    const dag = new DAG({
      onRepositionItem: () => {
        called++;
      },
    });
    dag.add("key1", "value1");
    dag.reposition("key1", { before: "key2" });
    assert.strictEqual(called, 1, "the callback was called");

    dag.reposition("key2", { before: "key1" });
    assert.strictEqual(called, 1, "the callback was not called");
  });

  test("returns the entries in the map", function (assert) {
    const entries: Array<[string, string, DAGPosition]> = [
      ["key1", "value1", { after: "key2" }],
      ["key2", "value2", { before: "key3" }],
      ["key3", "value3", { before: "key1" }],
    ];

    const dag = DAG.from(entries);
    const dagEntries = dag.entries();

    entries.forEach((entry, index) => {
      assert.strictEqual(dagEntries[index][0], entry[0], "the key is correct");
      assert.strictEqual(
        dagEntries[index][1],
        entry[1],
        "the value is correct"
      );
      assert.strictEqual(
        dagEntries[index][2]["before"],
        entry[2]["before"],
        "the before position is correct"
      );
      assert.strictEqual(
        dagEntries[index][2]["after"],
        entry[2]["after"],
        "the after position is correct"
      );
    });
  });

  test("resolves the map in the correct order", function (assert) {
    const dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2");
    dag.add("key3", "value3");

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key1", "key2", "key3"]);
  });

  test("allows for custom before and after default positioning", function (assert) {
    const dag = new DAG({ defaultPosition: { before: "key3", after: "key2" } });
    dag.add("key1", "value1", {});
    dag.add("key2", "value2", { after: "key1" });
    dag.add("key3", "value3", { after: "key2" });
    dag.add("key4", "value4");

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key1", "key2", "key4", "key3"]);

    assert.deepEqual(
      resolved.map((entry) => entry.position),
      [
        { before: undefined, after: undefined },
        { before: undefined, after: "key1" },
        { before: "key3", after: "key2" },
        { before: undefined, after: "key2" },
      ]
    );
  });

  test("resolves only existing keys", function (assert) {
    const dag = new DAG();
    dag.add("key1", "value1");
    dag.add("key2", "value2", { before: "key1" });
    dag.add("key3", "value3");

    dag.delete("key1");

    const resolved = dag.resolve();
    const keys = resolved.map((entry) => entry.key);

    assert.deepEqual(keys, ["key2", "key3"]);
  });

  test("throws on bad positioning", function (assert) {
    const dag = new DAG();

    assert.throws(
      () => dag.add("key1", "value1", { before: "key1" }),
      /cycle detected/
    );
  });

  test("add() that throws on a cycle does not leave the item behind", function (assert) {
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });

    // Closes a cycle (a -> b -> c -> a), so the add throws. A caller that
    // catches the throw expects "c" to be absent, not silently present and
    // mispositioned in resolve().
    assert.throws(
      () => dag.add("c", 3, { before: "a", after: "b" }),
      /cycle detected/
    );

    assert.false(dag.has("c"), "the item is not present after a failed add");
    assert.deepEqual(
      resolveKeys(dag),
      ["a", "b"],
      "resolve() does not include the item whose add threw"
    );
  });

  test("throwErrorOnCycle false: stale edges cleaned up on array constraint cycle", function (assert) {
    // When a before/after array partially applies (some edges succeed,
    // then a later one cycles), the successful edges must be rolled
    // back before retrying with the default position.
    const dag = new DAG({
      throwErrorOnCycle: false,
      defaultPosition: { before: "end" },
    });
    dag.add("start", 1);
    dag.add("middle", 2, { after: "start" });
    dag.add("end", 3, { after: "middle" });

    // "trouble" tries before:["start","middle"] + after:"end".
    // before-start and before-middle edges are added, then after-end
    // creates a cycle (end -> trouble -> start -> middle -> end).
    // Without rollback, the stale before-start and before-middle
    // edges push trouble to the very beginning of the sort.
    dag.add("trouble", 4, { before: ["start", "middle"], after: "end" });

    // With rollback: trouble gets default { before: "end" }, placing
    // it between middle and end.
    assert.deepEqual(resolveKeys(dag), ["start", "middle", "trouble", "end"]);
  });

  test("throwErrorOnCycle false: graceful fallback when default position also cycles", function (assert) {
    // When the original position cycles and the default position also
    // cycles, the item should be added with no constraints rather
    // than throwing.
    const dag = new DAG({
      throwErrorOnCycle: false,
      defaultPosition: { before: "base" },
    });
    dag.add("base", 1);
    // mid's { before: "trouble" } creates an edge mid->trouble,
    // giving trouble an inEdge before it is explicitly added.
    dag.add("mid", 2, { after: "base", before: "trouble" });

    // trouble tries { before: "base" } which cycles (base->mid->trouble->base).
    // Default { before: "base" } also cycles (same path).
    // Should gracefully add with no constraints.
    dag.add("trouble", 3, { after: "mid", before: "base" });

    assert.true(dag.has("trouble"), "trouble was added despite double cycle");

    // trouble still appears after mid because of mid's { before: "trouble" }
    assert.deepEqual(resolveKeys(dag), ["base", "mid", "trouble"]);
  });

  test("resolve returns cached result when DAG is not mutated", function (assert) {
    // Instance-level cache: repeated resolve() calls on the same
    // unmutated DAG return the exact same array reference.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });

    const first = dag.resolve();
    const second = dag.resolve();
    assert.strictEqual(first, second, "same reference on repeated resolve()");

    // Mutation invalidates the cache
    dag.add("c", 3);
    const third = dag.resolve();
    assert.notStrictEqual(first, third, "new reference after mutation");
  });

  test("cycle fallback uses each DAG's own defaultPosition", function (assert) {
    // Two DAGs with the same items but a different defaultPosition resolve
    // the same cycle to different orders, each using its own fallback.
    const items: Array<[string, string, DAGPosition]> = [
      ["a", "a", { after: "b" }],
      ["b", "b", { after: "a" }], // cycle a <-> b
      ["c", "c", {}],
    ];

    const first = DAG.from(items, {
      throwErrorOnCycle: false,
      defaultPosition: { before: "c" },
    });
    assert.deepEqual(
      resolveKeys(first),
      ["b", "a", "c"],
      "first DAG resolves the cycle using its own defaultPosition"
    );

    const second = DAG.from(items, {
      throwErrorOnCycle: false,
      defaultPosition: { after: "c" },
    });
    assert.deepEqual(
      resolveKeys(second),
      ["c", "b", "a"],
      "second DAG uses its own defaultPosition"
    );
  });

  test("resolve() returns a frozen array", function (assert) {
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2);

    const resolved = dag.resolve();

    assert.true(Object.isFrozen(resolved), "the resolved array is frozen");
    assert.throws(
      () => resolved.push({ key: "c", value: 3, position: {} }),
      /extensible/,
      "mutating the resolved array throws"
    );
  });

  /* after locality */

  test("single after: item placed immediately after anchor", function (assert) {
    // b { after: a } => a, b with no gap between them.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });

    assert.deepEqual(resolveKeys(dag), ["a", "b"]);
  });

  test("after chain stays together", function (assert) {
    // a->b->c forms a chain. Anchoring is recursive, so each link
    // ranks immediately after its predecessor.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });
    dag.add("c", 3, { after: "b" });

    assert.deepEqual(resolveKeys(dag), ["a", "b", "c"]);
  });

  test("after chain with branch: chain stays together, branch at end", function (assert) {
    // Both b and c depend on a. b also has a successor d.
    // d nests inside b's group, and b outranks c by registration
    // order, so the a->b->d chain comes before c.
    //
    //   a -> b -> d
    //    \-> c
    //
    // Expected: a, b, d, c
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });
    dag.add("c", 3, { after: "a" });
    dag.add("d", 4, { after: "b" });

    assert.deepEqual(
      resolveKeys(dag),
      ["a", "b", "d", "c"],
      "A->B->D chain together, then C"
    );
  });

  test("multiple items after same anchor: grouped in insertion order", function (assert) {
    // Three items all say { after: "anchor" }. They all become ready
    // when anchor is placed, and are visited in insertion order.
    //
    // Expected: anchor, first, second, third
    const dag = new DAG();
    dag.add("anchor", 0);
    dag.add("first", 1, { after: "anchor" });
    dag.add("second", 2, { after: "anchor" });
    dag.add("third", 3, { after: "anchor" });

    const result = resolveKeys(dag);
    assert.strictEqual(result[0], "anchor");
    assert.deepEqual(result.slice(1), ["first", "second", "third"]);
  });

  test("unrelated items do not drift between anchor and after items", function (assert) {
    // "unrelated" has no constraints. Without locality, a naive sort
    // could place it between a and b. Anchored items rank right next
    // to their anchor, keeping a->b together.
    //
    // Expected: a, b, unrelated
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });
    dag.add("unrelated", 3);

    assert.deepEqual(
      resolveKeys(dag),
      ["a", "b", "unrelated"],
      "unrelated goes after the a->b pair"
    );
  });

  /* before locality */

  test("single before: item placed immediately before target", function (assert) {
    // b { before: a } => b, a with no gap.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { before: "a" });

    assert.deepEqual(resolveKeys(dag), ["b", "a"]);
  });

  test("multiple items before same target: grouped in insertion order", function (assert) {
    // Both first and second say { before: "target" }. They share the
    // same anchor side, so they rank consecutively before target in
    // registration order.
    //
    // Expected: first, second, target
    const dag = new DAG();
    dag.add("target", 0);
    dag.add("first", 1, { before: "target" });
    dag.add("second", 2, { before: "target" });

    const result = resolveKeys(dag);
    const targetIdx = result.indexOf("target");

    assert.true(result.indexOf("first") < targetIdx, "first is before target");
    assert.true(
      result.indexOf("second") < targetIdx,
      "second is before target"
    );
    assert.strictEqual(
      targetIdx,
      result.length - 1,
      "target is last (all predecessors before it)"
    );
  });

  test("unrelated items do not drift between before items and target", function (assert) {
    // b and c both say { before: a }. "unrelated" has no constraints.
    // A naive insertion-order sort would place "unrelated" between the
    // before-items and their target; anchoring ranks b and c right
    // before a instead, keeping unrelated at the end.
    //
    // Expected: b, c, a, unrelated
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { before: "a" });
    dag.add("unrelated", 3);
    dag.add("c", 4, { before: "a" });

    const result = resolveKeys(dag);
    const aIdx = result.indexOf("a");

    assert.true(result.indexOf("b") < aIdx, "b is before a");
    assert.true(result.indexOf("c") < aIdx, "c is before a");
    assert.true(
      result.indexOf("unrelated") > aIdx,
      "unrelated does not drift between before-items and target"
    );
  });

  test("before with many predecessors and unrelated items", function (assert) {
    // p1, p2, p3 all say { before: "target" }. "unrelated" sits
    // between p1 and p2 in insertion order, but the anchored items
    // are grouped right before target, pushing unrelated to the end.
    //
    // Expected: p1, p2, p3, target, unrelated
    const dag = new DAG();
    dag.add("target", 0);
    dag.add("p1", 1, { before: "target" });
    dag.add("unrelated", 2);
    dag.add("p2", 3, { before: "target" });
    dag.add("p3", 4, { before: "target" });

    const result = resolveKeys(dag);
    const targetIdx = result.indexOf("target");

    assert.true(result.indexOf("p1") < targetIdx, "p1 before target");
    assert.true(result.indexOf("p2") < targetIdx, "p2 before target");
    assert.true(result.indexOf("p3") < targetIdx, "p3 before target");
    assert.true(
      result.indexOf("unrelated") > targetIdx,
      "unrelated after target, not between predecessors"
    );
  });

  /* Mixed constraints */

  test("before and after on the same node", function (assert) {
    // c says { before: b, after: a }, so c must appear between a and b.
    //
    // Expected: a, c, b
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2);
    dag.add("c", 3, { before: "b", after: "a" });

    assert.deepEqual(
      resolveKeys(dag),
      ["a", "c", "b"],
      "c is after a and before b"
    );
  });

  test("diamond pattern", function (assert) {
    // Classic diamond: a at the top, b and c in the middle, d at
    // the bottom depending on both b and c.
    //
    //   a -> b -> d
    //    \-> c -/
    //
    // Expected: a first, d last, b and c in between.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });
    dag.add("c", 3, { after: "a" });
    dag.add("d", 4, { after: ["b", "c"] });

    const result = resolveKeys(dag);
    assert.strictEqual(result[0], "a", "a is first");
    assert.strictEqual(result[result.length - 1], "d", "d is last");
    assert.true(result.indexOf("b") < result.indexOf("d"));
    assert.true(result.indexOf("c") < result.indexOf("d"));
  });

  test("two independent before/after pairs stay separate", function (assert) {
    // Two unrelated pairs: (beforeA, a) and (b, afterB).
    // Each pair should be immediately adjacent, and the pairs
    // should not interleave.
    //
    // Expected: beforeA, a, b, afterB
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2);
    dag.add("beforeA", 3, { before: "a" });
    dag.add("afterB", 4, { after: "b" });

    const result = resolveKeys(dag);
    const beforeAIdx = result.indexOf("beforeA");
    const aIdx = result.indexOf("a");
    const bIdx = result.indexOf("b");
    const afterBIdx = result.indexOf("afterB");

    assert.true(beforeAIdx < aIdx, "beforeA is before a");
    assert.true(bIdx < afterBIdx, "b is before afterB");
    assert.strictEqual(aIdx - beforeAIdx, 1, "beforeA is immediately before a");
    assert.strictEqual(afterBIdx - bIdx, 1, "afterB is immediately after b");
  });

  test("before array and after array constraints", function (assert) {
    // d says { before: [b, c], after: a }, so d must come after a
    // and before both b and c.
    //
    // Expected: a, d, b, c
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2);
    dag.add("c", 3);
    dag.add("d", 4, { before: ["b", "c"], after: "a" });

    const result = resolveKeys(dag);
    assert.true(result.indexOf("a") < result.indexOf("d"), "d is after a");
    assert.true(result.indexOf("d") < result.indexOf("b"), "d is before b");
    assert.true(result.indexOf("d") < result.indexOf("c"), "d is before c");
  });

  /* Complex sequences */

  test("long chain with plugins inserting at different points", function (assert) {
    // Core defines a 5-item chain: a -> b -> c -> d -> e.
    // Three plugins each attach to a different point in the chain.
    // The core chain stays together because within each anchor group
    // the earlier-registered chain link outranks the plugin item.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });
    dag.add("c", 3, { after: "b" });
    dag.add("d", 4, { after: "c" });
    dag.add("e", 5, { after: "d" });
    dag.add("p1", 6, { after: "a" });
    dag.add("p2", 7, { after: "b" });
    dag.add("p3", 8, { after: "d" });

    const result = resolveKeys(dag);

    assert.deepEqual(
      result.slice(0, 5),
      ["a", "b", "c", "d", "e"],
      "core chain stays contiguous"
    );
  });

  test("multiple plugins with before constraints on the same target", function (assert) {
    // Core: header -> content -> footer. Four plugins say { before: "footer" }.
    // All four group right before footer, sidebar at the end.
    const dag = new DAG();
    dag.add("header", 1);
    dag.add("content", 2, { after: "header" });
    dag.add("footer", 3, { after: "content" });
    dag.add("plugin-a", 4, { before: "footer" });
    dag.add("sidebar", 5);
    dag.add("plugin-b", 6, { before: "footer" });
    dag.add("plugin-c", 7, { before: "footer" });
    dag.add("plugin-d", 8, { before: "footer" });

    const result = resolveKeys(dag);
    const footerIdx = result.indexOf("footer");

    for (const plugin of ["plugin-a", "plugin-b", "plugin-c", "plugin-d"]) {
      assert.true(
        result.indexOf(plugin) < footerIdx,
        `${plugin} before footer`
      );
    }
    assert.true(result.indexOf("sidebar") > footerIdx, "sidebar after footer");
  });

  test("two merging chains with shared sink", function (assert) {
    //   a1 -> a2 -> a3 -\
    //                     -> merge -> final
    //   b1 -> b2 -------/
    const dag = new DAG();
    dag.add("a1", 1);
    dag.add("a2", 2, { after: "a1" });
    dag.add("a3", 3, { after: "a2" });
    dag.add("b1", 4);
    dag.add("b2", 5, { after: "b1" });
    dag.add("merge", 6, { after: ["a3", "b2"] });
    dag.add("final", 7, { after: "merge" });

    const result = resolveKeys(dag);

    assert.deepEqual(
      [result.indexOf("a1"), result.indexOf("a2"), result.indexOf("a3")],
      [0, 1, 2],
      "a-chain is contiguous at the start"
    );
    assert.deepEqual(
      [result.indexOf("b1"), result.indexOf("b2")],
      [3, 4],
      "b-chain is contiguous after a-chain"
    );
    assert.strictEqual(result.indexOf("merge"), 5);
    assert.strictEqual(result.indexOf("final"), 6);
  });

  test("before chain: predecessors form their own chain before a target", function (assert) {
    // p1 -> p2 -> p3 -> target, all constrained. Unrelated at end.
    //
    // Expected: p1, p2, p3, target, unrelated
    const dag = new DAG();
    dag.add("target", 1);
    dag.add("p1", 2, { before: "target" });
    dag.add("p2", 3, { before: "target", after: "p1" });
    dag.add("p3", 4, { before: "target", after: "p2" });
    dag.add("unrelated", 5);

    assert.deepEqual(resolveKeys(dag), [
      "p1",
      "p2",
      "p3",
      "target",
      "unrelated",
    ]);
  });

  test("wide fan-out: one root with many independent successors", function (assert) {
    // root has 8 successors. They all group after root, with
    // unrelated items at the end.
    const dag = new DAG();
    dag.add("root", 0);
    dag.add("unrelated-1", 1);
    dag.add("s1", 2, { after: "root" });
    dag.add("s2", 3, { after: "root" });
    dag.add("unrelated-2", 4);
    dag.add("s3", 5, { after: "root" });
    dag.add("s4", 6, { after: "root" });
    dag.add("s5", 7, { after: "root" });
    dag.add("s6", 8, { after: "root" });
    dag.add("s7", 9, { after: "root" });
    dag.add("s8", 10, { after: "root" });

    const result = resolveKeys(dag);

    assert.strictEqual(result[0], "root");
    assert.deepEqual(
      result.slice(1, 9),
      ["s1", "s2", "s3", "s4", "s5", "s6", "s7", "s8"],
      "all successors grouped after root"
    );
    assert.deepEqual(
      result.slice(9),
      ["unrelated-1", "unrelated-2"],
      "unrelated items after the fan-out group"
    );
  });

  test("wide fan-in: many independent predecessors converge on one target", function (assert) {
    // 6 predecessors before target, with unrelated items interspersed.
    // All predecessors group contiguously before target.
    const dag = new DAG();
    dag.add("target", 0);
    dag.add("p1", 1, { before: "target" });
    dag.add("p2", 2, { before: "target" });
    dag.add("unrelated-1", 3);
    dag.add("p3", 4, { before: "target" });
    dag.add("p4", 5, { before: "target" });
    dag.add("unrelated-2", 6);
    dag.add("p5", 7, { before: "target" });
    dag.add("p6", 8, { before: "target" });

    const result = resolveKeys(dag);
    const targetIdx = result.indexOf("target");

    assert.deepEqual(
      result.slice(0, 6),
      ["p1", "p2", "p3", "p4", "p5", "p6"],
      "all predecessors are contiguous"
    );
    assert.true(
      result.indexOf("unrelated-1") > targetIdx,
      "unrelated-1 after target"
    );
    assert.true(
      result.indexOf("unrelated-2") > targetIdx,
      "unrelated-2 after target"
    );
  });

  test("complex toolbar: mixed before/after with sub-groups", function (assert) {
    // Core: bold -> italic -> underline -> separator-1 -> link ->
    //       image -> separator-2 -> undo -> redo
    // Plugins pin between core items using both constraints.
    const dag = new DAG();
    dag.add("bold", 1);
    dag.add("italic", 2, { after: "bold" });
    dag.add("underline", 3, { after: "italic" });
    dag.add("separator-1", 4, { after: "underline" });
    dag.add("link", 5, { after: "separator-1" });
    dag.add("image", 6, { after: "link" });
    dag.add("separator-2", 7, { after: "image" });
    dag.add("undo", 8, { after: "separator-2" });
    dag.add("redo", 9, { after: "undo" });
    dag.add("strikethrough", 10, { before: "separator-1", after: "underline" });
    dag.add("emoji", 11, { before: "separator-2", after: "image" });
    dag.add("code", 12, { before: "link", after: "separator-1" });

    const result = resolveKeys(dag);

    const coreItems = [
      "bold",
      "italic",
      "underline",
      "separator-1",
      "link",
      "image",
      "separator-2",
      "undo",
      "redo",
    ];
    for (let i = 1; i < coreItems.length; i++) {
      assert.true(
        result.indexOf(coreItems[i - 1]) < result.indexOf(coreItems[i]),
        `${coreItems[i - 1]} before ${coreItems[i]}`
      );
    }

    assert.true(
      result.indexOf("strikethrough") > result.indexOf("underline"),
      "strikethrough after underline"
    );
    assert.true(
      result.indexOf("strikethrough") < result.indexOf("separator-1"),
      "strikethrough before separator-1"
    );
    assert.true(
      result.indexOf("code") > result.indexOf("separator-1"),
      "code after separator-1"
    );
    assert.true(
      result.indexOf("code") < result.indexOf("link"),
      "code before link"
    );
    assert.true(
      result.indexOf("emoji") > result.indexOf("image"),
      "emoji after image"
    );
    assert.true(
      result.indexOf("emoji") < result.indexOf("separator-2"),
      "emoji before separator-2"
    );
  });

  /* Real-world patterns */

  test("header icons pattern: items before search", function (assert) {
    // lang-switcher and color-selector before search, after-chain follows.
    const dag = new DAG();
    dag.add("search", 1);
    dag.add("hamburger", 2, { after: "search" });
    dag.add("user-menu", 3, { after: "hamburger" });
    dag.add("lang-switcher", 4, { before: "search" });
    dag.add("color-selector", 5, { before: "search", after: "lang-switcher" });

    const result = resolveKeys(dag);
    const searchIdx = result.indexOf("search");

    assert.true(result.indexOf("lang-switcher") < searchIdx);
    assert.true(result.indexOf("color-selector") < searchIdx);
    assert.true(
      result.indexOf("color-selector") > result.indexOf("lang-switcher")
    );
    assert.true(result.indexOf("hamburger") > searchIdx);
  });

  test("post menu pattern: items before show-more", function (assert) {
    // Core buttons without constraints, then items before show-more.
    const dag = new DAG();
    dag.add("like", 1);
    dag.add("share", 2);
    dag.add("flag", 3);
    dag.add("show-more", 4);
    dag.add("bookmark", 5, { before: "show-more" });
    dag.add("reply", 6, { before: "show-more" });
    dag.add("plugin-btn", 7, { before: "show-more" });

    const result = resolveKeys(dag);
    const showMoreIdx = result.indexOf("show-more");

    assert.true(result.indexOf("bookmark") < showMoreIdx);
    assert.true(result.indexOf("reply") < showMoreIdx);
    assert.true(result.indexOf("plugin-btn") < showMoreIdx);
  });

  /* Hub graphs: a defaultPosition pointing at one key gives that key a
     very high in-degree. Locality must survive that shape. */

  test("hub fan-in: before/after pair stays adjacent under a hub", function (assert) {
    // a, b, and unrelated all point at the hub. attached anchors after a,
    // so it must sit right between a and b; unrelated must not drift in.
    const dag = new DAG();
    dag.add("a", 1, { before: "hub" });
    dag.add("b", 2, { before: "hub" });
    dag.add("hub", 3);
    dag.add("unrelated", 4, { before: "hub" });
    dag.add("attached", 5, { after: "a", before: "b" });

    assert.deepEqual(resolveKeys(dag), [
      "a",
      "attached",
      "b",
      "unrelated",
      "hub",
    ]);
  });

  test("hub fan-in: item registered last with before-first leads the group", function (assert) {
    // prepended anchors before the group's first item, so registration
    // order must not sink it into the middle of the hub's predecessors.
    const dag = new DAG();
    dag.add("first", 1, { before: "hub" });
    dag.add("second", 2, { before: "hub" });
    dag.add("third", 3, { before: "hub" });
    dag.add("hub", 4);
    dag.add("prepended", 5, { before: "first" });

    assert.deepEqual(resolveKeys(dag), [
      "prepended",
      "first",
      "second",
      "third",
      "hub",
    ]);
  });

  test("hub via defaultPosition: anchored items keep their anchors adjacent", function (assert) {
    // Mirrors the post menu: every core button gets { before: "showMore" },
    // so showMore is a hub. Items added later with explicit anchors must
    // land next to those anchors, not where registration order puts them.
    const dag = new DAG({
      defaultPosition: { before: "showMore" },
      throwErrorOnCycle: false,
    });
    dag.add("read", 1, { before: ["showMore"] });
    dag.add("like", 2, { before: ["showMore"] });
    dag.add("copyLink", 3, { before: ["showMore"] });
    dag.add("showMore", 4, {});
    dag.add("reply", 5, { after: ["showMore"] });
    dag.add("plugin-first", 6, { before: "read" });
    dag.add("plugin-last", 7);
    dag.add("plugin-mid", 8, { after: "like", before: "copyLink" });
    dag.add("plugin-orphan", 9, { after: "absent-key" });

    assert.deepEqual(resolveKeys(dag), [
      "plugin-first",
      "read",
      "like",
      "plugin-mid",
      "copyLink",
      "plugin-last",
      "showMore",
      "reply",
      "plugin-orphan",
    ]);
  });

  test("absent after-anchor: item sorts at the end", function (assert) {
    // "missing" is referenced but never added, so it renders nothing and
    // sorts past every real item; the item anchored after it follows it
    // there instead of staying where it was registered, which would give
    // a, ghost-follower, b
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("ghost-follower", 2, { after: "missing" });
    dag.add("b", 3);

    assert.deepEqual(resolveKeys(dag), ["a", "b", "ghost-follower"]);
  });

  test("hub: a lone after-anchor lands adjacent, not past the hub", function (assert) {
    // A single anchor has to be enough on its own. The anchor's edge into
    // the hub must not drag its follower along: reaching "attached" only
    // through the hub would sort it last, giving
    // first, second, third, hub, trailing, attached
    const dag = new DAG(hubOptions());
    addHubGroup(dag);
    dag.add("attached", 6, { after: "first" });

    assert.deepEqual(resolveKeys(dag), [
      "first",
      "attached",
      "second",
      "third",
      "hub",
      "trailing",
    ]);
  });

  test("hub: anchoring after the last item before the hub", function (assert) {
    // "third" is the last item before the hub, so its follower belongs in
    // the gap between the two rather than beyond the hub's own successors,
    // which would give first, second, third, hub, trailing, attached
    const dag = new DAG(hubOptions());
    addHubGroup(dag);
    dag.add("attached", 6, { after: "third" });

    assert.deepEqual(resolveKeys(dag), [
      "first",
      "second",
      "third",
      "attached",
      "hub",
      "trailing",
    ]);
  });

  /* Single-anchor sufficiency: one anchor fully determines placement, so a
     second opposing anchor is redundant rather than load-bearing. */

  test("one anchor places an item identically to an anchor pair", function (assert) {
    // Callers should not have to name an opposing anchor to pin an item
    // down. Both forms resolve to
    // first, attached, second, third, hub, trailing
    // where a sort that honours only the pair would leave the single form
    // at first, second, third, hub, trailing, attached
    const single = new DAG(hubOptions());
    addHubGroup(single);
    single.add("attached", 6, { after: "first" });

    const pair = new DAG(hubOptions());
    addHubGroup(pair);
    pair.add("attached", 6, { after: "first", before: "second" });

    assert.deepEqual(
      resolveKeys(single),
      resolveKeys(pair),
      "the redundant before-anchor does not change the result"
    );
  });

  test("sequential surface: a lone after-anchor does not displace its anchor", function (assert) {
    // Surfaces without a defaultPosition add their items unconstrained.
    // Giving "gamma" a follower must not move "gamma" itself: pushing the
    // pair to the end would reorder the untouched items too, giving
    // alpha, beta, delta, epsilon, gamma, inserted
    const dag = new DAG();
    for (const key of ["alpha", "beta", "gamma", "delta", "epsilon"]) {
      dag.add(key, key);
    }
    dag.add("inserted", 9, { after: "gamma" });

    assert.deepEqual(resolveKeys(dag), [
      "alpha",
      "beta",
      "gamma",
      "inserted",
      "delta",
      "epsilon",
    ]);
  });

  test("chain of after-links stays contiguous", function (assert) {
    // Each link anchors to the previous one, so the whole chain trails the
    // item it was appended to.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2);
    dag.add("c", 3);
    dag.add("x1", 4, { after: "c" });
    dag.add("x2", 5, { after: "x1" });
    dag.add("x3", 6, { after: "x2" });

    assert.deepEqual(resolveKeys(dag), ["a", "b", "c", "x1", "x2", "x3"]);
  });

  test("contested anchor: followers group in registration order", function (assert) {
    // Two items claim the slot after the same anchor. Both join the
    // anchor's group, earlier registration first, rather than the later
    // one being left at its registration point:
    // anchor, early-follower, tail, late-follower
    const dag = new DAG();
    dag.add("anchor", 1);
    dag.add("early-follower", 2, { after: "anchor" });
    dag.add("tail", 3);
    dag.add("late-follower", 4, { after: "anchor" });

    assert.deepEqual(resolveKeys(dag), [
      "anchor",
      "early-follower",
      "late-follower",
      "tail",
    ]);
  });

  /* Before-side mirrors of the guarantees above. The two sides are ranked
     by separate branches, so each needs its own coverage. */

  test("hub: a lone before-anchor lands adjacent", function (assert) {
    const dag = new DAG(hubOptions());
    addHubGroup(dag);
    dag.add("attached", 6, { before: "third" });

    assert.deepEqual(resolveKeys(dag), [
      "first",
      "second",
      "attached",
      "third",
      "hub",
      "trailing",
    ]);
  });

  test("sequential surface: a lone before-anchor does not displace its anchor", function (assert) {
    const dag = new DAG();
    for (const key of ["alpha", "beta", "gamma", "delta", "epsilon"]) {
      dag.add(key, key);
    }
    dag.add("inserted", 9, { before: "gamma" });

    assert.deepEqual(resolveKeys(dag), [
      "alpha",
      "beta",
      "inserted",
      "gamma",
      "delta",
      "epsilon",
    ]);
  });

  test("chain of before-links stays contiguous", function (assert) {
    // Each link anchors before the previous one, so the chain builds
    // backwards and lands ahead of the item it was anchored to.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2);
    dag.add("c", 3);
    dag.add("x1", 4, { before: "a" });
    dag.add("x2", 5, { before: "x1" });
    dag.add("x3", 6, { before: "x2" });

    assert.deepEqual(resolveKeys(dag), ["x3", "x2", "x1", "a", "b", "c"]);
  });

  test("a lone before array anchors to the nearest listed key", function (assert) {
    // Listing several keys means "ahead of all of them"; the item settles
    // against the closest one rather than the furthest.
    const dag = new DAG();
    dag.add("p", 1);
    dag.add("q", 2);
    dag.add("r", 3);
    dag.add("multi", 4, { before: ["q", "r"] });

    assert.deepEqual(resolveKeys(dag), ["p", "multi", "q", "r"]);
  });

  test("absent before-anchor is ignored", function (assert) {
    // Mirrors "absent after-anchor" and is deliberately asymmetric: an
    // absent key sorts past every real item, so a before-constraint on it
    // is vacuous and the item keeps its own position, while an
    // after-constraint on it would carry the item to the end.
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("ghost", 2, { before: "missing" });
    dag.add("b", 3);

    assert.deepEqual(resolveKeys(dag), ["a", "ghost", "b"]);
  });

  test("before and after together: the after anchor decides placement", function (assert) {
    // Both anchors are honoured as ordering edges, but they disagree about
    // where the item belongs. It hugs what it follows, so it sits against
    // "w" rather than drifting down to "z".
    const dag = new DAG();
    dag.add("w", 1);
    dag.add("x", 2);
    dag.add("y", 3);
    dag.add("z", 4);
    dag.add("mid", 5, { after: "w", before: "z" });

    assert.deepEqual(resolveKeys(dag), ["w", "mid", "x", "y", "z"]);
  });

  /* replace/reposition cycle handling */

  test("replace with cycle-creating position throws and leaves DAG unchanged", function (assert) {
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });
    dag.add("c", 3, { after: "b" });

    assert.throws(
      () => dag.replace("a", "new-value", { after: "c" }),
      /cycle detected/
    );

    assert.deepEqual(
      resolveKeys(dag),
      ["a", "b", "c"],
      "DAG order unchanged after failed replace"
    );
    assert.deepEqual(
      dag.resolve().map((e) => e.value),
      [1, 2, 3],
      "values unchanged after failed replace"
    );
  });

  test("reposition with cycle-creating position throws and leaves DAG unchanged", function (assert) {
    const dag = new DAG();
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });
    dag.add("c", 3, { after: "b" });

    assert.throws(() => dag.reposition("a", { after: "c" }), /cycle detected/);

    assert.deepEqual(
      resolveKeys(dag),
      ["a", "b", "c"],
      "DAG order unchanged after failed reposition"
    );
  });

  test("replace with cycle and throwErrorOnCycle false falls back gracefully", function (assert) {
    const dag = new DAG({
      throwErrorOnCycle: false,
      defaultPosition: { before: "c" },
    });
    dag.add("a", 1);
    dag.add("b", 2, { after: "a" });
    dag.add("c", 3, { after: "b" });

    dag.replace("a", "new-value", { after: "c" });

    assert.true(dag.has("a"), "a still exists");
    const result = dag.resolve();
    assert.strictEqual(
      result.find((e) => e.key === "a").value,
      "new-value",
      "value was updated"
    );
  });
});
