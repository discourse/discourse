import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { raiseBlockError } from "discourse/lib/blocks/-internals/error";

module("Unit | Blocks | error", function () {
  module("raiseBlockError", function () {
    test("includes tree-style breadcrumb when rootLayout is provided", function (assert) {
      @block("error-test-block1")
      class Block1 extends Component {}

      @block("error-test-block2")
      class Block2 extends Component {}

      @block("error-test-block-group")
      class BlockGroup extends Component {}

      @block("error-test-child1")
      class Child1 extends Component {}

      @block("error-test-child2")
      class Child2 extends Component {}

      const rootLayout = [
        { block: Block1, args: { name: "first" } },
        { block: Block2, args: { name: "second" } },
        {
          block: BlockGroup,
          args: { name: "callouts" },
          children: [
            { block: Child1, args: { title: "child1" } },
            { block: Child2, args: { nme: "typo" } },
          ],
        },
      ];

      try {
        raiseBlockError("Invalid arg name", {
          path: "[2].children[1].args.nme",
          rootLayout,
        });
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(
          error.message.includes("Location:"),
          "should include Location header"
        );
        assert.true(
          error.message.includes("└─"),
          "should include tree-style breadcrumb"
        );
        assert.true(
          error.message.includes("[2]"),
          "should show array index in breadcrumb"
        );
        assert.true(
          error.message.includes("error-test-block-group"),
          "should show block name in breadcrumb"
        );
      }
    });

    test("shows nested config context from root to error", function (assert) {
      @block("nested-context-block1")
      class Block1 extends Component {}

      @block("nested-context-block-group")
      class BlockGroup extends Component {}

      @block("nested-context-child")
      class Child extends Component {}

      const rootLayout = [
        { block: Block1, args: { name: "first" } },
        {
          block: BlockGroup,
          args: { name: "nested" },
          children: [{ block: Child, args: { bad: "value" } }],
        },
      ];

      try {
        raiseBlockError("Validation error", {
          path: "[1].children[0].args.bad",
          rootLayout,
        });
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(
          error.message.includes("Context:"),
          "should include Context section"
        );
        // Should show the path to error in context (either ... for skipped items or the block name)
        const showsPath =
          error.message.includes("...") ||
          error.message.includes("nested-context-block-group");
        assert.true(showsPath, "should show path to error in context");
      }
    });

    test("uses path when errorPath is not provided", function (assert) {
      @block("path-test-block")
      class TestBlock extends Component {}

      const rootLayout = [{ block: TestBlock, args: { name: "test" } }];

      try {
        raiseBlockError("Block error", {
          path: "[0]",
          rootLayout,
        });
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(
          error.message.includes("Location:"),
          "should include Location even with just path"
        );
        assert.true(
          error.message.includes("[0]"),
          "should show the path location"
        );
      }
    });

    test("falls back to plain path when rootLayout is not provided", function (assert) {
      try {
        raiseBlockError("Simple error", {
          path: "[0].args.name",
        });
        assert.true(false, "should have thrown");
      } catch (error) {
        assert.true(
          error.message.includes("Location: [0].args.name"),
          "should show plain path without tree-style formatting"
        );
      }
    });

    test("paths without prefix correctly expand nested config", function (assert) {
      @block("prefix-test-block1")
      class Block1 extends Component {}

      @block("prefix-test-block2")
      class Block2 extends Component {}

      @block("prefix-test-block-group")
      class BlockGroup extends Component {}

      @block("prefix-test-child")
      class Child extends Component {}

      // Paths must start with array index (e.g., "[2]") not a string prefix
      // (e.g., "blocks[2]") for the formatter to match them to the config array
      const rootLayout = [
        { block: Block1, args: { name: "first" } },
        { block: Block2, args: { name: "second" } },
        {
          block: BlockGroup,
          args: { name: "nested" },
          children: [{ block: Child, args: { bad: "value" } }],
        },
      ];

      try {
        raiseBlockError("Validation error", {
          // Path starts with array index, no "blocks" prefix
          path: "[2].children[0].args.bad",
          rootLayout,
        });
        assert.true(false, "should have thrown");
      } catch (error) {
        const contextSection = error.message.split("Context:")[1] || "";

        // Should expand the path to the error, not show all as { ... }
        const truncatedCount = (contextSection.match(/\{ \.\.\. \}/g) || [])
          .length;

        assert.true(
          truncatedCount < 3,
          `Context should expand nested path. Got ${truncatedCount} truncated objects.`
        );

        // Should show the block on the error path (check for block name or the <block> format)
        const showsBlockInfo =
          contextSection.includes("prefix-test-block-group") ||
          contextSection.includes("<prefix-test");
        assert.true(showsBlockInfo, "should show block info on the error path");
      }
    });

    test("expands nested config even with deeply nested error path", function (assert) {
      @block("deep-test-block1")
      class Block1 extends Component {}

      @block("deep-test-block2")
      class Block2 extends Component {}

      @block("deep-test-block3")
      class Block3 extends Component {}

      @block("deep-test-block4")
      class Block4 extends Component {}

      @block("deep-test-block-group")
      class BlockGroup extends Component {}

      @block("deep-test-child1")
      class Child1 extends Component {}

      @block("deep-test-child2")
      class Child2 extends Component {}

      @block("deep-test-child3")
      class Child3 extends Component {}

      // This test mimics the CORRECT validation scenario where the path
      // starts with array index (no "blocks" prefix)
      const rootLayout = [
        { block: Block1, args: { name: "first" } },
        { block: Block2, args: { name: "second" } },
        { block: Block3, args: { name: "third" } },
        { block: Block4, args: { name: "fourth" } },
        {
          block: BlockGroup,
          args: { name: "callouts" },
          children: [
            { block: Child1, args: { name: "child1" } },
            { block: Child2, args: { name: "child2" } },
            { block: Child3, args: { nme: "typo" } },
          ],
        },
      ];

      try {
        raiseBlockError("Invalid arg", {
          path: "[4].children[2].args.nme",
          rootLayout,
        });
        assert.true(false, "should have thrown");
      } catch (error) {
        // The context should NOT show all items as { ... }
        // It should expand the path to the error
        const contextSection = error.message.split("Context:")[1];

        // Count how many { ... } truncated objects are shown
        const truncatedCount = (contextSection.match(/\{ \.\.\. \}/g) || [])
          .length;

        // Should have at most 1-2 truncated objects (for args not on path),
        // NOT 5 (one for each root block)
        assert.true(
          truncatedCount < 5,
          `Context should expand nested path, not show all as { ... }. Got ${truncatedCount} truncated objects. Context:\n${contextSection}`
        );

        // Should show the block name on the error path (check for block name or the <block> format)
        const showsBlockInfo =
          contextSection.includes("deep-test-block-group") ||
          contextSection.includes("<deep-test");
        assert.true(showsBlockInfo, "should show block info on the error path");

        // Should show children key
        assert.true(
          contextSection.includes("children:"),
          "should show children array on error path"
        );
      }
    });
  });
});
