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

module("Integration | Blocks | BlockGroup", function (hooks) {
  setupRenderingTest(hooks);

  test("renders with BEM classes", async function (assert) {
    @block("group-child-1")
    class GroupChild1 extends Component {
      <template>
        <div class="child-1">Child 1</div>
      </template>
    }

    @block("group-child-2")
    class GroupChild2 extends Component {
      <template>
        <div class="child-2">Child 2</div>
      </template>
    }

    withTestBlockRegistration(() => {
      _registerBlock(GroupChild1);
      _registerBlock(GroupChild2);
    });
    renderBlocks("hero-blocks", [
      {
        block: BlockGroup,
        args: { group: "features" },
        classNames: "custom-group-class",
        children: [{ block: GroupChild1 }, { block: GroupChild2 }],
      },
    ]);

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".hero-blocks__group").exists();
    assert.dom(".block__group-features").exists();
    assert.dom(".custom-group-class").exists();
  });

  test("renders all children blocks", async function (assert) {
    @block("multi-child-a")
    class MultiChildA extends Component {
      <template>
        <div class="multi-a">A</div>
      </template>
    }

    @block("multi-child-b")
    class MultiChildB extends Component {
      <template>
        <div class="multi-b">B</div>
      </template>
    }

    @block("multi-child-c")
    class MultiChildC extends Component {
      <template>
        <div class="multi-c">C</div>
      </template>
    }

    withTestBlockRegistration(() => {
      _registerBlock(MultiChildA);
      _registerBlock(MultiChildB);
      _registerBlock(MultiChildC);
    });
    renderBlocks("homepage-blocks", [
      {
        block: BlockGroup,
        children: [
          { block: MultiChildA },
          { block: MultiChildB },
          { block: MultiChildC },
        ],
      },
    ]);

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".multi-a").exists();
    assert.dom(".multi-b").exists();
    assert.dom(".multi-c").exists();
  });

  test("passes args to children blocks", async function (assert) {
    @block("args-child")
    class ArgsChild extends Component {
      <template>
        <div class="args-child-content">{{@title}}</div>
      </template>
    }

    withTestBlockRegistration(() => _registerBlock(ArgsChild));
    renderBlocks("sidebar-blocks", [
      {
        block: BlockGroup,
        children: [
          { block: ArgsChild, args: { title: "First" } },
          { block: ArgsChild, args: { title: "Second" } },
        ],
      },
    ]);

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    const contents = document.querySelectorAll(".args-child-content");
    assert.strictEqual(contents.length, 2);
    assert.strictEqual(contents[0].textContent.trim(), "First");
    assert.strictEqual(contents[1].textContent.trim(), "Second");
  });

  test("supports nested BlockGroups", async function (assert) {
    @block("nested-leaf")
    class NestedLeaf extends Component {
      <template>
        <div class="nested-leaf">Leaf</div>
      </template>
    }

    withTestBlockRegistration(() => _registerBlock(NestedLeaf));
    renderBlocks("main-outlet-blocks", [
      {
        block: BlockGroup,
        args: { group: "outer" },
        children: [
          {
            block: BlockGroup,
            args: { group: "inner" },
            children: [{ block: NestedLeaf }],
          },
        ],
      },
    ]);

    await render(
      <template><BlockOutlet @name="main-outlet-blocks" /></template>
    );

    assert.dom(".block__group-outer").exists();
    assert.dom(".block__group-inner").exists();
    assert.dom(".nested-leaf").exists();
  });
});
