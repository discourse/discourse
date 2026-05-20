import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  cloneEntryForPaste,
  cloneLayoutForDraft,
  entryKey,
  findEntry,
  insertEntryAt,
  moveEntry,
  removeEntry,
  replaceEntryArgs,
  replaceEntryContainerArgs,
  replaceEntryId,
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

  module("replaceEntryContainerArgs", function () {
    function makeGridLayout() {
      return [
        {
          block: ContainerBlock,
          args: { mode: "grid" },
          __stableKey: 10,
          children: [
            {
              block: LeafBlock,
              args: { title: "Cell A" },
              containerArgs: {
                grid: { column: "1", row: "1", align: "stretch" },
              },
              __stableKey: 11,
            },
            {
              block: LeafBlock,
              args: { title: "Cell B" },
              containerArgs: {
                grid: { column: "2", row: "1", align: "stretch" },
              },
              __stableKey: 12,
            },
          ],
        },
      ];
    }

    test("replaces the named namespace bag wholesale", function (assert) {
      const layout = makeGridLayout();
      const { layout: next, changed } = replaceEntryContainerArgs(
        layout,
        "ve:mutate-test-leaf:11",
        "grid",
        (current) => ({ ...current, column: "3", row: "2" })
      );

      assert.true(changed);
      assert.deepEqual(next[0].children[0].containerArgs.grid, {
        column: "3",
        row: "2",
        align: "stretch",
      });
    });

    test("preserves sibling namespaces under containerArgs", function (assert) {
      const layout = [
        {
          block: ContainerBlock,
          args: { mode: "grid" },
          __stableKey: 20,
          children: [
            {
              block: LeafBlock,
              args: {},
              containerArgs: {
                grid: { column: "1", row: "1" },
                stack: { order: 5 },
              },
              __stableKey: 21,
            },
          ],
        },
      ];

      const { layout: next } = replaceEntryContainerArgs(
        layout,
        "ve:mutate-test-leaf:21",
        "grid",
        () => ({ column: "2", row: "2" })
      );

      assert.deepEqual(next[0].children[0].containerArgs.stack, { order: 5 });
      assert.deepEqual(next[0].children[0].containerArgs.grid, {
        column: "2",
        row: "2",
      });
    });

    test("creates the namespace bag if it doesn't exist yet", function (assert) {
      const layout = [
        {
          block: ContainerBlock,
          args: {},
          __stableKey: 30,
          children: [
            {
              block: LeafBlock,
              args: {},
              __stableKey: 31,
            },
          ],
        },
      ];

      const { layout: next, changed } = replaceEntryContainerArgs(
        layout,
        "ve:mutate-test-leaf:31",
        "grid",
        () => ({ column: "1", row: "1" })
      );

      assert.true(changed);
      assert.deepEqual(next[0].children[0].containerArgs.grid, {
        column: "1",
        row: "1",
      });
    });

    test("preserves identity of untouched siblings", function (assert) {
      const layout = makeGridLayout();
      const siblingOriginal = layout[0].children[1];

      const { layout: next } = replaceEntryContainerArgs(
        layout,
        "ve:mutate-test-leaf:11",
        "grid",
        (current) => ({ ...current, column: "3" })
      );

      assert.strictEqual(
        next[0].children[1],
        siblingOriginal,
        "untouched sibling keeps identity"
      );
    });

    test("returns the original layout when no entry matches", function (assert) {
      const layout = makeGridLayout();
      const { layout: next, changed } = replaceEntryContainerArgs(
        layout,
        "nope:0",
        "grid",
        () => ({})
      );

      assert.false(changed);
      assert.strictEqual(next, layout);
    });
  });

  module("replaceEntryId", function () {
    function makeIdLayout() {
      return [
        {
          block: ContainerBlock,
          args: {},
          __stableKey: 60,
          children: [
            {
              block: LeafBlock,
              args: { title: "Inner" },
              __stableKey: 61,
            },
            {
              block: LeafBlock,
              args: { title: "Inner 2" },
              id: "untouched",
              __stableKey: 62,
            },
          ],
        },
      ];
    }

    test("sets the id on the matched entry, preserves __stableKey", function (assert) {
      const layout = makeIdLayout();
      const { layout: next, changed } = replaceEntryId(
        layout,
        "ve:mutate-test-leaf:61",
        "hero"
      );

      assert.true(changed);
      assert.strictEqual(next[0].children[0].id, "hero");
      assert.strictEqual(next[0].children[0].__stableKey, 61);
    });

    test("preserves identity of untouched siblings", function (assert) {
      const layout = makeIdLayout();
      const siblingOriginal = layout[0].children[1];

      const { layout: next } = replaceEntryId(
        layout,
        "ve:mutate-test-leaf:61",
        "hero"
      );

      assert.strictEqual(next[0].children[1], siblingOriginal);
    });

    test("clears the id property when passed null", function (assert) {
      const layout = makeIdLayout();
      const { layout: next, changed } = replaceEntryId(
        layout,
        "ve:mutate-test-leaf:62",
        null
      );

      assert.true(changed);
      assert.false(
        "id" in next[0].children[1],
        "the id property is dropped, not just set to null"
      );
    });

    test("clears the id property when passed an empty string", function (assert) {
      const layout = makeIdLayout();
      const { layout: next, changed } = replaceEntryId(
        layout,
        "ve:mutate-test-leaf:62",
        ""
      );

      assert.true(changed);
      assert.false("id" in next[0].children[1]);
    });

    test("returns the original layout when no entry matches", function (assert) {
      const layout = makeIdLayout();
      const { layout: next, changed } = replaceEntryId(
        layout,
        "nope:0",
        "hero"
      );

      assert.false(changed);
      assert.strictEqual(next, layout);
    });
  });

  module("cloneLayoutForDraft / cloneEntryForPaste", function () {
    test("deep-clones containerArgs so draft mutations don't leak", function (assert) {
      const layout = [
        {
          block: LeafBlock,
          args: { title: "Hi" },
          containerArgs: {
            grid: { column: "1", row: "2" },
          },
          __stableKey: 40,
        },
      ];
      const cloned = cloneLayoutForDraft(layout);

      assert.notStrictEqual(
        cloned[0].containerArgs,
        layout[0].containerArgs,
        "containerArgs is a fresh object"
      );
      assert.notStrictEqual(
        cloned[0].containerArgs.grid,
        layout[0].containerArgs.grid,
        "each namespace bag is a fresh object"
      );

      cloned[0].containerArgs.grid.column = "5";

      assert.strictEqual(
        layout[0].containerArgs.grid.column,
        "1",
        "mutating the clone does not affect the source"
      );
    });

    test("strips null and undefined args during clone", function (assert) {
      // Self-heal for layouts persisted before the write-side fix landed
      // (FormKit cleared text inputs used to land as `null` in args).
      const layout = [
        {
          block: LeafBlock,
          args: {
            title: "Hi",
            name: null,
            role: undefined,
            ctaLabel: "",
            count: 0,
            enabled: false,
          },
          containerArgs: {
            grid: { column: "1", row: null, align: undefined },
          },
        },
      ];

      const cloned = cloneLayoutForDraft(layout);

      assert.deepEqual(cloned[0].args, {
        title: "Hi",
        ctaLabel: "",
        count: 0,
        enabled: false,
      });
      assert.deepEqual(cloned[0].containerArgs.grid, {
        column: "1",
      });
    });

    test("strips validator soft-failure stamps from the source entry", function (assert) {
      // The source layer's validator may have stamped `__failureType` /
      // `__failureReason` / `__visible` on its entries. Those describe
      // the source layer's state, not the draft's — and the draft's own
      // validator will re-stamp if the issue is real. Carrying them
      // over would paint stale error chrome on entries whose args we
      // then sanitise in `cloneEntryForDraft`.
      const layout = [
        {
          block: LeafBlock,
          args: { title: "Hi" },
          __failureType: "structural-invalid",
          __failureReason: "stale message from a previous validation pass",
          __visible: false,
        },
      ];

      const cloned = cloneLayoutForDraft(layout);

      assert.false("__failureType" in cloned[0]);
      assert.false("__failureReason" in cloned[0]);
      assert.false("__visible" in cloned[0]);
    });

    test("cloneEntryForPaste also deep-clones containerArgs", function (assert) {
      const entry = {
        block: LeafBlock,
        args: { title: "Hi" },
        containerArgs: { grid: { column: "3", row: "1" } },
        __stableKey: 50,
      };
      const cloned = cloneEntryForPaste(entry);

      assert.strictEqual(cloned.__stableKey, undefined, "stableKey stripped");
      cloned.containerArgs.grid.column = "9";
      assert.strictEqual(entry.containerArgs.grid.column, "3");
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
