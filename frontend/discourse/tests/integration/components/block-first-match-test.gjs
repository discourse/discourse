import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import BlockFirstMatch from "discourse/blocks/builtin/block-first-match";
import BlockGroup from "discourse/blocks/builtin/block-group";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockFirstMatch", function (hooks) {
  setupRenderingTest(hooks);

  test("renders only the first child when all children are visible", async function (assert) {
    @block("first-match-child-a")
    class ChildA extends Component {
      <template>
        <div class="child-a">A</div>
      </template>
    }

    @block("first-match-child-b")
    class ChildB extends Component {
      <template>
        <div class="child-b">B</div>
      </template>
    }

    @block("first-match-child-c")
    class ChildC extends Component {
      <template>
        <div class="child-c">C</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(ChildA);
      registerBlock(ChildB);
      registerBlock(ChildC);
    });
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockFirstMatch,
          children: [{ block: ChildA }, { block: ChildB }, { block: ChildC }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".child-a").exists("first child renders");
    assert.dom(".child-b").doesNotExist("second child does not render");
    assert.dom(".child-c").doesNotExist("third child does not render");
  });

  test("renders first child whose conditions pass", async function (assert) {
    @block("conditional-child-1")
    class ConditionalChild1 extends Component {
      <template>
        <div class="cond-1">First</div>
      </template>
    }

    @block("conditional-child-2")
    class ConditionalChild2 extends Component {
      <template>
        <div class="cond-2">Second</div>
      </template>
    }

    @block("conditional-child-3")
    class ConditionalChild3 extends Component {
      <template>
        <div class="cond-3">Third</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(ConditionalChild1);
      registerBlock(ConditionalChild2);
      registerBlock(ConditionalChild3);
    });
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockFirstMatch,
          children: [
            // First child fails condition (user is not admin in test)
            {
              block: ConditionalChild1,
              conditions: { type: "user", admin: true },
            },
            // Second child passes (no conditions)
            { block: ConditionalChild2 },
            // Third child also passes but shouldn't render
            { block: ConditionalChild3 },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert
      .dom(".cond-1")
      .doesNotExist("first child with failing condition does not render");
    assert.dom(".cond-2").exists("second child (first passing) renders");
    assert.dom(".cond-3").doesNotExist("third child does not render");
  });

  test("renders nothing when no children pass conditions", async function (assert) {
    @block("all-fail-child")
    class AllFailChild extends Component {
      <template>
        <div class="fail-child">Should not render</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(AllFailChild));
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockFirstMatch,
          children: [
            {
              block: AllFailChild,
              conditions: { type: "user", admin: true },
            },
            {
              block: AllFailChild,
              conditions: { type: "user", staff: true },
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert
      .dom(".fail-child")
      .doesNotExist("no children render when all conditions fail");
  });

  test("renders with correct BEM classes", async function (assert) {
    @block("bem-test-child")
    class BemTestChild extends Component {
      <template>
        <div class="bem-child">Child</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(BemTestChild));
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockFirstMatch,
          classNames: "custom-first-match",
          children: [{ block: BemTestChild }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".hero-blocks__first-match").exists("has outlet-prefixed class");
    assert.dom(".block-first-match").exists("has block class");
    assert.dom(".custom-first-match").exists("has custom class");
  });

  test("works nested inside a group", async function (assert) {
    @block("nested-first-a")
    class NestedFirstA extends Component {
      <template>
        <div class="nested-a">A</div>
      </template>
    }

    @block("nested-first-b")
    class NestedFirstB extends Component {
      <template>
        <div class="nested-b">B</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(NestedFirstA);
      registerBlock(NestedFirstB);
    });
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockGroup,
          args: { name: "outer" },
          children: [
            {
              block: BlockFirstMatch,
              children: [{ block: NestedFirstA }, { block: NestedFirstB }],
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".block-group-outer").exists("group renders");
    assert.dom(".nested-a").exists("first-match renders first child");
    assert
      .dom(".nested-b")
      .doesNotExist("first-match does not render second child");
  });

  test("passes args to the rendered child", async function (assert) {
    @block("args-first-child", { args: { message: { type: "string" } } })
    class ArgsFirstChild extends Component {
      <template>
        <div class="args-child">{{@message}}</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(ArgsFirstChild));
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockFirstMatch,
          children: [
            {
              block: ArgsFirstChild,
              args: { message: "Hello from first-match" },
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".args-child").hasText("Hello from first-match");
  });

  test("@outletName is accessible in the rendered child", async function (assert) {
    @block("outlet-name-first-child")
    class OutletNameFirstChild extends Component {
      <template>
        <div
          class="outlet-display"
          data-outlet={{@outletName}}
        >{{@outletName}}</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(OutletNameFirstChild));
    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: BlockFirstMatch,
          children: [{ block: OutletNameFirstChild }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    const display = document.querySelector(".outlet-display");
    assert.strictEqual(display.getAttribute("data-outlet"), "sidebar-blocks");
    assert.strictEqual(display.textContent.trim(), "sidebar-blocks");
  });
});
