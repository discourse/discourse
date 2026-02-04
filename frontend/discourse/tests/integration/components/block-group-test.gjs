import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import BlockGroup from "discourse/blocks/builtin/block-group";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  DEBUG_CALLBACK,
  debugHooks,
  registerBlock,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockGroup", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, null);
  });

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
      registerBlock(GroupChild1);
      registerBlock(GroupChild2);
    });
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockGroup,
          args: { name: "features" },
          classNames: "custom-group-class",
          children: [{ block: GroupChild1 }, { block: GroupChild2 }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".hero-blocks__group").exists();
    assert.dom(".block-group-features").exists();
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
      registerBlock(MultiChildA);
      registerBlock(MultiChildB);
      registerBlock(MultiChildC);
    });
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockGroup,
          args: { name: "multi-children" },
          children: [
            { block: MultiChildA },
            { block: MultiChildB },
            { block: MultiChildC },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".multi-a").exists();
    assert.dom(".multi-b").exists();
    assert.dom(".multi-c").exists();
  });

  test("passes args to children blocks", async function (assert) {
    @block("args-child", { args: { title: { type: "string" } } })
    class ArgsChild extends Component {
      <template>
        <div class="args-child-content">{{@title}}</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(ArgsChild));
    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: BlockGroup,
          args: { name: "args-children" },
          children: [
            { block: ArgsChild, args: { title: "First" } },
            { block: ArgsChild, args: { title: "Second" } },
          ],
        },
      ])
    );

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

    withTestBlockRegistration(() => registerBlock(NestedLeaf));
    withPluginApi((api) =>
      api.renderBlocks("main-outlet-blocks", [
        {
          block: BlockGroup,
          args: { name: "outer" },
          children: [
            {
              block: BlockGroup,
              args: { name: "inner" },
              children: [{ block: NestedLeaf }],
            },
          ],
        },
      ])
    );

    await render(
      <template><BlockOutlet @name="main-outlet-blocks" /></template>
    );

    assert.dom(".block-group-outer").exists();
    assert.dom(".block-group-inner").exists();
    assert.dom(".nested-leaf").exists();
  });

  test("children blocks have outlet-prefixed wrapper classes", async function (assert) {
    @block("wrapper-test-child")
    class WrapperTestChild extends Component {
      <template>
        <span class="child-content">Child</span>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(WrapperTestChild));
    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: BlockGroup,
          args: { name: "wrapper-test" },
          children: [{ block: WrapperTestChild }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    // Container block wrapper should have outlet-prefixed class
    assert
      .dom(".sidebar-blocks__group")
      .exists("container has outlet-prefixed class");
    assert.dom(".block-group").exists("container has block-group class");

    // Child block wrapper should have outlet-prefixed class
    assert
      .dom(".sidebar-blocks__block")
      .exists("child has outlet-prefixed __block class");
    assert
      .dom(".block-wrapper-test-child")
      .exists("child has block-{name} class");
  });

  test("deeply nested blocks have correct outlet-prefixed wrapper classes", async function (assert) {
    @block("deep-leaf")
    class DeepLeaf extends Component {
      <template>
        <span class="deep-leaf-content">Leaf</span>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(DeepLeaf));
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockGroup,
          args: { name: "level-1" },
          children: [
            {
              block: BlockGroup,
              args: { name: "level-2" },
              children: [
                {
                  block: BlockGroup,
                  args: { name: "level-3" },
                  children: [{ block: DeepLeaf }],
                },
              ],
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // All nested containers should have the same outlet prefix
    assert.dom(".hero-blocks__group").exists({ count: 3 });

    // The leaf block should also have the outlet prefix
    assert
      .dom(".hero-blocks__block")
      .exists("deeply nested leaf has outlet-prefixed class");
    assert
      .dom(".block-deep-leaf")
      .exists("deeply nested leaf has block-{name} class");
  });

  test("@outletName is curried and accessible in blocks", async function (assert) {
    @block("outlet-name-test")
    class OutletNameTest extends Component {
      <template>
        <div class="outlet-name-display" data-outlet={{@outletName}}>
          {{@outletName}}
        </div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(OutletNameTest));
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockGroup,
          args: { name: "parent" },
          children: [{ block: OutletNameTest }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    const display = document.querySelector(".outlet-name-display");
    assert.strictEqual(
      display.getAttribute("data-outlet"),
      "homepage-blocks",
      "@outletName is curried into nested blocks"
    );
    assert.strictEqual(
      display.textContent.trim(),
      "homepage-blocks",
      "@outletName value is accessible in template"
    );
  });

  test("wrapper classes are correct when debug overlay is enabled", async function (assert) {
    @block("overlay-test-child")
    class OverlayTestChild extends Component {
      <template>
        <span class="overlay-child-content" data-outlet={{@outletName}}>
          Child
        </span>
      </template>
    }

    // Enable debug overlay - this wraps blocks with BlockInfo component
    debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData) => {
      return { Component: blockData.Component };
    });

    withTestBlockRegistration(() => registerBlock(OverlayTestChild));
    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: BlockGroup,
          args: { name: "overlay-test" },
          children: [{ block: OverlayTestChild }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    // Verify container has correct outlet-prefixed class even with overlay
    assert
      .dom(".sidebar-blocks__group")
      .exists("container has outlet-prefixed class with overlay enabled");

    // Verify child has correct outlet-prefixed class even with overlay
    assert
      .dom(".sidebar-blocks__block")
      .exists("child has outlet-prefixed class with overlay enabled");

    // Verify @outletName is still accessible to the block component
    const childContent = document.querySelector(".overlay-child-content");
    assert.strictEqual(
      childContent.getAttribute("data-outlet"),
      "sidebar-blocks",
      "@outletName is accessible even when overlay wraps the component"
    );
  });

  test("deeply nested wrapper classes are correct with debug overlay enabled", async function (assert) {
    @block("deep-overlay-leaf")
    class DeepOverlayLeaf extends Component {
      <template>
        <span class="deep-overlay-content" data-outlet={{@outletName}}>
          Leaf
        </span>
      </template>
    }

    // Enable debug overlay
    debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData) => {
      return { Component: blockData.Component };
    });

    withTestBlockRegistration(() => registerBlock(DeepOverlayLeaf));
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockGroup,
          args: { name: "level-1" },
          children: [
            {
              block: BlockGroup,
              args: { name: "level-2" },
              children: [{ block: DeepOverlayLeaf }],
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // All nested containers should have outlet prefix with overlay enabled
    assert
      .dom(".hero-blocks__group")
      .exists({ count: 2 }, "nested containers have outlet-prefixed class");

    // The deeply nested leaf should have outlet prefix
    assert
      .dom(".hero-blocks__block")
      .exists("deeply nested leaf has outlet-prefixed class with overlay");

    // @outletName should be accessible in deeply nested blocks
    const leafContent = document.querySelector(".deep-overlay-content");
    assert.strictEqual(
      leafContent.getAttribute("data-outlet"),
      "hero-blocks",
      "@outletName is accessible in deeply nested blocks with overlay"
    );
  });

  test("containerArgs are accessible to parent container", async function (assert) {
    // A tabs-like container that requires each child to provide a name via containerArgs.
    // The parent can access containerArgs to render tab headers.
    @block("tabs-container", {
      container: true,
      childArgs: {
        tabName: { type: "string", required: true, unique: true },
      },
      classNames: "tabs-container",
    })
    class TabsContainer extends Component {
      <template>
        <div class="tabs-header">
          {{#each @children as |child|}}
            <button class="tab-button" data-tab={{child.containerArgs.tabName}}>
              {{child.containerArgs.tabName}}
            </button>
          {{/each}}
        </div>
        <div class="tabs-content">
          {{#each @children as |child|}}
            <child.Component />
          {{/each}}
        </div>
      </template>
    }

    @block("tab-content")
    class TabContent extends Component {
      <template>
        <div class="tab-panel">Tab Panel Content</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(TabsContainer);
      registerBlock(TabContent);
    });
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: TabsContainer,
          children: [
            { block: TabContent, containerArgs: { tabName: "settings" } },
            { block: TabContent, containerArgs: { tabName: "profile" } },
            { block: TabContent, containerArgs: { tabName: "security" } },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // Verify tab headers are rendered from containerArgs
    const tabButtons = document.querySelectorAll(".tab-button");
    assert.strictEqual(tabButtons.length, 3, "three tab buttons rendered");
    assert.strictEqual(
      tabButtons[0].getAttribute("data-tab"),
      "settings",
      "first tab has correct name from containerArgs"
    );
    assert.strictEqual(
      tabButtons[1].getAttribute("data-tab"),
      "profile",
      "second tab has correct name from containerArgs"
    );
    assert.strictEqual(
      tabButtons[2].getAttribute("data-tab"),
      "security",
      "third tab has correct name from containerArgs"
    );

    // Verify tab content panels are rendered
    const tabPanels = document.querySelectorAll(".tab-panel");
    assert.strictEqual(tabPanels.length, 3, "three tab panels rendered");
  });
});
