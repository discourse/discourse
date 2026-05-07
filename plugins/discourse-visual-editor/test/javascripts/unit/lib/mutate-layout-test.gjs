import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import {
  entryKey,
  findEntry,
  replaceEntryArgs,
  setEntryArg,
} from "discourse/plugins/discourse-visual-editor/discourse/lib/mutate-layout";

@block("mutate-test:leaf")
class LeafBlock extends Component {
  <template>leaf</template>
}

@block("mutate-test:container", { container: true })
class ContainerBlock extends Component {
  <template>
    <div class="container">{{yield}}</div>
  </template>
}

function makeLayout() {
  return [
    {
      block: "mutate-test:leaf",
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
      const entry = { block: "mutate-test:leaf", __stableKey: 7 };
      assert.strictEqual(entryKey(entry), "mutate-test:leaf:7");
    });

    test("returns the composite key for class-referenced entries", function (assert) {
      const entry = { block: LeafBlock, __stableKey: 9 };
      assert.strictEqual(entryKey(entry), "mutate-test:leaf:9");
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
      const found = findEntry(layout, "mutate-test:leaf:1");
      assert.strictEqual(found, layout[0]);
    });

    test("finds a nested entry by composite key", function (assert) {
      const layout = makeLayout();
      const found = findEntry(layout, "mutate-test:leaf:3");
      assert.strictEqual(found, layout[1].children[0]);
    });

    test("returns null when the key isn't present", function (assert) {
      const layout = makeLayout();
      assert.strictEqual(findEntry(layout, "mutate-test:leaf:999"), null);
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
        "mutate-test:leaf:1",
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
        "mutate-test:leaf:3",
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
        "mutate-test:container:2",
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
        "mutate-test:leaf:42",
        "title",
        "Goodbye"
      );
      assert.deepEqual(next[0].args, { title: "Goodbye", subtitle: "World" });
    });
  });
});
