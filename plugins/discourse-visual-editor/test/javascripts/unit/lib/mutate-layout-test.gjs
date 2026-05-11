import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  entryKey,
  findEntry,
  insertEntryAt,
  moveEntry,
  removeEntry,
  replaceEntryArgs,
  setEntryArg,
} from "discourse/plugins/discourse-visual-editor/discourse/lib/mutate-layout";

@block("ve:mutate-test-leaf")
class LeafBlock extends Component {
  <template>leaf</template>
}

@block("ve:mutate-test-container", { container: true })
class ContainerBlock extends Component {
  <template>
    <div class="container">{{yield}}</div>
  </template>
}

function makeLayout() {
  return [
    {
      block: "ve:mutate-test-leaf",
      args: { title: "First" },
      __stableKey: 1,
    },
    {
      block: ContainerBlock,
      args: { gap: 8 },
      __stableKey: 2,
      children: [
        {
          block: LeafBlock,
          args: { title: "Nested" },
          __stableKey: 3,
        },
      ],
    },
  ];
}

module("Unit | Discourse Visual Editor | mutate-layout", function () {
  module("entryKey", function () {
    test("returns the composite key for string-referenced entries", function (assert) {
      const entry = { block: "ve:mutate-test-leaf", __stableKey: 7 };
      assert.strictEqual(entryKey(entry), "ve:mutate-test-leaf:7");
    });

    test("returns the composite key for class-referenced entries", function (assert) {
      const entry = { block: LeafBlock, __stableKey: 9 };
      assert.strictEqual(entryKey(entry), "ve:mutate-test-leaf:9");
    });

    test("returns null when the entry has no stableKey", function (assert) {
      assert.strictEqual(entryKey({ block: LeafBlock }), null);
    });

    test("returns null for unresolvable class references", function (assert) {
      class NotABlock {}
      const entry = { block: NotABlock, __stableKey: 1 };
      assert.strictEqual(entryKey(entry), null);
    });
  });

  module("findEntry", function () {
    test("finds a top-level entry by composite key", function (assert) {
      const layout = makeLayout();
      const found = findEntry(layout, "ve:mutate-test-leaf:1");
      assert.strictEqual(found, layout[0]);
    });

    test("finds a nested entry by composite key", function (assert) {
      const layout = makeLayout();
      const found = findEntry(layout, "ve:mutate-test-leaf:3");
      assert.strictEqual(found, layout[1].children[0]);
    });

    test("returns null when the key isn't present", function (assert) {
      const layout = makeLayout();
      assert.strictEqual(findEntry(layout, "ve:mutate-test-leaf:999"), null);
    });

    test("returns null for null/undefined layouts", function (assert) {
      assert.strictEqual(findEntry(null, "any"), null);
      assert.strictEqual(findEntry(undefined, "any"), null);
    });
  });

  module("replaceEntryArgs", function () {
    test("replaces args at the matched entry, leaves everything else by reference", function (assert) {
      const layout = makeLayout();
      const original = layout[0];
      const containerOriginal = layout[1];
      const nestedOriginal = layout[1].children[0];

      const { layout: next, changed } = replaceEntryArgs(
        layout,
        "ve:mutate-test-leaf:1",
        (current) => ({ ...current, title: "Updated" })
      );

      assert.true(changed, "reports a change");
      assert.notStrictEqual(
        next[0],
        original,
        "matched entry is a fresh object"
      );
      assert.strictEqual(
        next[1],
        containerOriginal,
        "untouched siblings keep their identity"
      );
      assert.strictEqual(
        next[1].children[0],
        nestedOriginal,
        "untouched descendants keep their identity"
      );
      assert.strictEqual(next[0].args.title, "Updated");
      assert.strictEqual(
        next[0].__stableKey,
        1,
        "preserves __stableKey on the replaced entry"
      );
    });

    test("replaces args on a nested entry", function (assert) {
      const layout = makeLayout();
      const containerOriginal = layout[1];

      const { layout: next, changed } = replaceEntryArgs(
        layout,
        "ve:mutate-test-leaf:3",
        () => ({ title: "Replaced" })
      );

      assert.true(changed);
      assert.notStrictEqual(
        next[1],
        containerOriginal,
        "ancestors of the matched entry are cloned"
      );
      assert.strictEqual(next[1].children[0].args.title, "Replaced");
    });

    test("returns the same children reference when nothing changed in a subtree", function (assert) {
      const layout = makeLayout();
      const { layout: next, changed } = replaceEntryArgs(
        layout,
        "nope:0",
        () => ({})
      );

      assert.false(changed);
      assert.strictEqual(next[1], layout[1]);
      assert.strictEqual(next[1].children, layout[1].children);
    });
  });

  module("setEntryArg", function () {
    test("immutably sets a single arg on the matched entry", function (assert) {
      const layout = makeLayout();
      const { layout: next, changed } = setEntryArg(
        layout,
        "ve:mutate-test-container:2",
        "gap",
        16
      );
      assert.true(changed);
      assert.strictEqual(next[1].args.gap, 16);
      assert.strictEqual(layout[1].args.gap, 8, "original layout untouched");
    });

    test("preserves other args on the same entry", function (assert) {
      const layout = [
        {
          block: LeafBlock,
          args: { title: "Hello", subtitle: "World" },
          __stableKey: 42,
        },
      ];
      const { layout: next } = setEntryArg(
        layout,
        "ve:mutate-test-leaf:42",
        "title",
        "Goodbye"
      );
      assert.deepEqual(next[0].args, { title: "Goodbye", subtitle: "World" });
    });
  });

  module("removeEntry", function () {
    test("removes a top-level entry and returns it", function (assert) {
      const layout = makeLayout();
      const original = layout[0];
      const containerOriginal = layout[1];

      const result = removeEntry(layout, "ve:mutate-test-leaf:1");

      assert.true(result.changed);
      assert.strictEqual(result.removed, original);
      assert.strictEqual(result.layout.length, 1);
      assert.strictEqual(
        result.layout[0],
        containerOriginal,
        "untouched sibling keeps identity"
      );
    });

    test("removes a nested entry; ancestor is cloned, untouched siblings keep identity", function (assert) {
      const layout = [
        ...makeLayout(),
        {
          block: "ve:mutate-test-leaf",
          args: { title: "Trailing" },
          __stableKey: 99,
        },
      ];
      const trailingOriginal = layout[2];
      const containerOriginal = layout[1];

      const result = removeEntry(layout, "ve:mutate-test-leaf:3");

      assert.true(result.changed);
      assert.strictEqual(result.removed, containerOriginal.children[0]);
      assert.notStrictEqual(
        result.layout[1],
        containerOriginal,
        "ancestor of removed entry is cloned"
      );
      assert.strictEqual(
        result.layout[1].children.length,
        0,
        "container no longer holds the removed child"
      );
      assert.strictEqual(
        result.layout[2],
        trailingOriginal,
        "untouched trailing sibling keeps identity"
      );
    });

    test("returns the same layout reference when the key isn't present", function (assert) {
      const layout = makeLayout();
      const result = removeEntry(layout, "absent:0");

      assert.false(result.changed);
      assert.strictEqual(result.removed, null);
      assert.strictEqual(result.layout, layout);
    });
  });

  module("insertEntryAt", function () {
    test("inserts before a top-level target", function (assert) {
      const layout = makeLayout();
      const newEntry = {
        block: "ve:mutate-test-leaf",
        args: { title: "New" },
        __stableKey: 50,
      };
      const result = insertEntryAt(
        layout,
        "ve:mutate-test-container:2",
        newEntry,
        "before"
      );
      assert.true(result.changed);
      assert.strictEqual(result.layout.length, 3);
      assert.strictEqual(result.layout[0], layout[0]);
      assert.strictEqual(result.layout[1], newEntry);
      assert.strictEqual(result.layout[2], layout[1]);
    });

    test("inserts after a top-level target", function (assert) {
      const layout = makeLayout();
      const newEntry = {
        block: "ve:mutate-test-leaf",
        args: { title: "After" },
        __stableKey: 51,
      };
      const result = insertEntryAt(
        layout,
        "ve:mutate-test-leaf:1",
        newEntry,
        "after"
      );
      assert.true(result.changed);
      assert.strictEqual(result.layout[0], layout[0]);
      assert.strictEqual(result.layout[1], newEntry);
      assert.strictEqual(result.layout[2], layout[1]);
    });

    test("inserts inside a container as the first child", function (assert) {
      const layout = makeLayout();
      const newEntry = {
        block: "ve:mutate-test-leaf",
        args: { title: "Inside" },
        __stableKey: 52,
      };
      const result = insertEntryAt(
        layout,
        "ve:mutate-test-container:2",
        newEntry,
        "inside"
      );
      assert.true(result.changed);
      assert.strictEqual(result.layout[1].children.length, 2);
      assert.strictEqual(result.layout[1].children[0], newEntry);
      assert.strictEqual(
        result.layout[1].children[1],
        layout[1].children[0],
        "existing child keeps identity"
      );
    });

    test("appends to root when targetKey is null", function (assert) {
      const layout = makeLayout();
      const newEntry = {
        block: "ve:mutate-test-leaf",
        args: { title: "End" },
        __stableKey: 53,
      };
      const result = insertEntryAt(layout, null, newEntry, "after");
      assert.true(result.changed);
      assert.strictEqual(result.layout[result.layout.length - 1], newEntry);
    });

    test("returns changed=false when targetKey isn't present", function (assert) {
      const layout = makeLayout();
      const newEntry = {
        block: "ve:mutate-test-leaf",
        args: {},
        __stableKey: 54,
      };
      const result = insertEntryAt(layout, "absent:0", newEntry, "after");
      assert.false(result.changed);
    });
  });

  module("moveEntry", function () {
    test("reorders top-level siblings", function (assert) {
      const layout = makeLayout();
      const result = moveEntry(
        layout,
        "ve:mutate-test-leaf:1",
        "ve:mutate-test-container:2",
        "after"
      );
      assert.true(result.changed);
      assert.strictEqual(result.layout[0], layout[1], "container is now first");
      assert.strictEqual(
        result.layout[1].block,
        "ve:mutate-test-leaf",
        "leaf is now second"
      );
      assert.strictEqual(
        result.layout[1].__stableKey,
        1,
        "moved entry keeps its stable key"
      );
    });

    test("moves a top-level entry into a container", function (assert) {
      const layout = makeLayout();
      const result = moveEntry(
        layout,
        "ve:mutate-test-leaf:1",
        "ve:mutate-test-container:2",
        "inside"
      );
      assert.true(result.changed);
      assert.strictEqual(
        result.layout.length,
        1,
        "container is the sole top-level entry"
      );
      assert.strictEqual(result.layout[0].children.length, 2);
      assert.strictEqual(
        result.layout[0].children[0].__stableKey,
        1,
        "moved leaf is the new first child"
      );
    });

    test("moves a nested entry up to the root", function (assert) {
      const layout = makeLayout();
      const result = moveEntry(
        layout,
        "ve:mutate-test-leaf:3",
        "ve:mutate-test-leaf:1",
        "before"
      );
      assert.true(result.changed);
      assert.strictEqual(result.layout.length, 3);
      assert.strictEqual(
        result.layout[0].__stableKey,
        3,
        "moved entry is now at root, before the original first leaf"
      );
      assert.strictEqual(
        result.layout[2].children.length,
        0,
        "container no longer holds the moved child"
      );
    });

    test("rejects self-targeting moves", function (assert) {
      const layout = makeLayout();
      const result = moveEntry(
        layout,
        "ve:mutate-test-leaf:1",
        "ve:mutate-test-leaf:1",
        "after"
      );
      assert.false(result.changed);
      assert.strictEqual(result.layout, layout);
    });

    test("rejects moving a container into one of its own descendants", function (assert) {
      const layout = makeLayout();
      const result = moveEntry(
        layout,
        "ve:mutate-test-container:2",
        "ve:mutate-test-leaf:3",
        "before"
      );
      assert.false(result.changed, "self-nesting cycle is blocked");
      assert.strictEqual(result.layout, layout);
    });

    test("returns changed=false when source key is absent", function (assert) {
      const layout = makeLayout();
      const result = moveEntry(
        layout,
        "absent:0",
        "ve:mutate-test-leaf:1",
        "after"
      );
      assert.false(result.changed);
      assert.strictEqual(result.layout, layout);
    });

    test("returns changed=false when target key is absent", function (assert) {
      const layout = makeLayout();
      const result = moveEntry(
        layout,
        "ve:mutate-test-leaf:1",
        "absent:0",
        "after"
      );
      assert.false(result.changed);
      assert.strictEqual(result.layout, layout);
    });
  });
});
