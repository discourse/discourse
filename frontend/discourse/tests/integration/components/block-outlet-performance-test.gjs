import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockGroup from "discourse/blocks/block-group";
import BlockOutlet, {
  block,
  renderBlocks,
} from "discourse/components/block-outlet";
import {
  _registerBlock,
  withTestBlockRegistration,
} from "discourse/lib/blocks/registration";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockOutlet Performance", function (hooks) {
  setupRenderingTest(hooks);

  module("deeply nested containers", function () {
    test("renders 5+ levels of nested container blocks", async function (assert) {
      @block("leaf-block")
      class LeafBlock extends Component {
        <template>
          <div class="leaf-block" data-depth={{@depth}}>
            Leaf at depth
            {{@depth}}
          </div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(LeafBlock);
      });

      const buildNestedConfig = (depth, maxDepth) => {
        if (depth >= maxDepth) {
          return [
            { block: LeafBlock, args: { depth: depth.toString() } },
            { block: LeafBlock, args: { depth: depth.toString() } },
          ];
        }

        return [
          {
            block: BlockGroup,
            args: { group: `level-${depth}` },
            children: buildNestedConfig(depth + 1, maxDepth),
          },
          {
            block: BlockGroup,
            args: { group: `level-${depth}-alt` },
            children: buildNestedConfig(depth + 1, maxDepth),
          },
        ];
      };

      renderBlocks("homepage-blocks", buildNestedConfig(0, 5));

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".homepage-blocks").exists("outlet renders");

      assert.dom(".block__group-level-0").exists("level 0 group exists");
      assert.dom(".block__group-level-1").exists("level 1 group exists");
      assert.dom(".block__group-level-2").exists("level 2 group exists");
      assert.dom(".block__group-level-3").exists("level 3 group exists");
      assert.dom(".block__group-level-4").exists("level 4 group exists");

      const leafBlocks = document.querySelectorAll(".leaf-block");
      assert.strictEqual(
        leafBlocks.length,
        64,
        "all 64 leaf blocks render (2^6 from binary tree)"
      );

      const depth5Leaves = document.querySelectorAll(
        '.leaf-block[data-depth="5"]'
      );
      assert.strictEqual(
        depth5Leaves.length,
        64,
        "all leaf blocks are at depth 5"
      );
    });

    test("deeply nested blocks do not cause stack overflow", async function (assert) {
      @block("deep-leaf-block")
      class DeepLeafBlock extends Component {
        <template>
          <div class="deep-leaf">Deep Leaf</div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(DeepLeafBlock);
      });

      const buildDeeplyNestedConfig = (depth) => {
        if (depth <= 0) {
          return [{ block: DeepLeafBlock }];
        }

        return [
          {
            block: BlockGroup,
            args: { group: `deep-${depth}` },
            children: buildDeeplyNestedConfig(depth - 1),
          },
        ];
      };

      renderBlocks("sidebar-blocks", buildDeeplyNestedConfig(10));

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.dom(".sidebar-blocks").exists("outlet renders");

      assert.dom(".block__group-deep-10").exists("deepest group exists");
      assert.dom(".block__group-deep-1").exists("shallowest group exists");
      assert.dom(".deep-leaf").exists("leaf block renders at bottom");
    });

    test("nested containers with conditions at multiple levels", async function (assert) {
      @block("conditional-leaf")
      class ConditionalLeaf extends Component {
        <template>
          <div class="conditional-leaf" data-level={{@level}}>
            Level
            {{@level}}
          </div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(ConditionalLeaf);
      });

      renderBlocks("main-outlet-blocks", [
        {
          block: BlockGroup,
          args: { group: "outer" },
          children: [
            {
              block: BlockGroup,
              args: { group: "middle-1" },
              children: [
                {
                  block: ConditionalLeaf,
                  args: { level: "3a" },
                  conditions: { type: "user", loggedIn: false },
                },
                {
                  block: ConditionalLeaf,
                  args: { level: "3b" },
                },
              ],
            },
            {
              block: BlockGroup,
              args: { group: "middle-2" },
              conditions: { type: "user", loggedIn: false },
              children: [{ block: ConditionalLeaf, args: { level: "3c" } }],
            },
          ],
        },
      ]);

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".block__group-outer").exists("outer group renders");
      assert.dom(".block__group-middle-1").exists("middle-1 group renders");
      assert
        .dom('.conditional-leaf[data-level="3a"]')
        .doesNotExist("conditional leaf 3a hidden (logged out required)");
      assert
        .dom('.conditional-leaf[data-level="3b"]')
        .exists("unconditional leaf 3b renders");
      assert
        .dom(".block__group-middle-2")
        .doesNotExist("middle-2 group hidden (logged out required)");
      assert
        .dom('.conditional-leaf[data-level="3c"]')
        .doesNotExist("leaf 3c hidden (parent hidden)");
    });
  });
});
