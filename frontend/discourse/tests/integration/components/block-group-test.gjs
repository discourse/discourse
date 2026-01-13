import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockGroup from "discourse/blocks/block-group";
import BlockOutlet, {
  block,
  renderBlocks,
} from "discourse/blocks/block-outlet";
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
        args: { name: "features" },
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
        args: { name: "multi-children" },
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
    @block("args-child", { args: { title: { type: "string" } } })
    class ArgsChild extends Component {
      <template>
        <div class="args-child-content">{{@title}}</div>
      </template>
    }

    withTestBlockRegistration(() => _registerBlock(ArgsChild));
    renderBlocks("sidebar-blocks", [
      {
        block: BlockGroup,
        args: { name: "args-children" },
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
        args: { name: "outer" },
        children: [
          {
            block: BlockGroup,
            args: { name: "inner" },
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

  test("containerArgs are accessible to parent container", async function (assert) {
    // A tabs-like container that requires each child to provide a name via containerArgs.
    // The parent can access containerArgs to render tab headers.
    @block("tabs-container", {
      container: true,
      childArgs: {
        tabName: { type: "string", required: true, unique: true },
      },
    })
    class TabsContainer extends Component {
      <template>
        <div class="tabs-container">
          <div class="tabs-header">
            {{#each this.children as |child|}}
              <button
                class="tab-button"
                data-tab={{child.containerArgs.tabName}}
              >
                {{child.containerArgs.tabName}}
              </button>
            {{/each}}
          </div>
          <div class="tabs-content">
            {{#each this.children as |child|}}
              <child.Component />
            {{/each}}
          </div>
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
      _registerBlock(TabsContainer);
      _registerBlock(TabContent);
    });
    renderBlocks("header-blocks", [
      {
        block: TabsContainer,
        children: [
          { block: TabContent, containerArgs: { tabName: "settings" } },
          { block: TabContent, containerArgs: { tabName: "profile" } },
          { block: TabContent, containerArgs: { tabName: "security" } },
        ],
      },
    ]);

    await render(<template><BlockOutlet @name="header-blocks" /></template>);

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
