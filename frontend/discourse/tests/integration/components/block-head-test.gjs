import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import BlockGroup from "discourse/blocks/builtin/block-group";
import BlockHead from "discourse/blocks/builtin/block-head";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  FAILURE_TYPE,
  setupGhostCapture,
} from "discourse/tests/helpers/block-testing";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Blocks | BlockHead", function (hooks) {
  setupRenderingTest(hooks);

  test("renders only the first child when all children are visible", async function (assert) {
    @block("head-child-a")
    class ChildA extends Component {
      <template>
        <div class="child-a">A</div>
      </template>
    }

    @block("head-child-b")
    class ChildB extends Component {
      <template>
        <div class="child-b">B</div>
      </template>
    }

    @block("head-child-c")
    class ChildC extends Component {
      <template>
        <div class="child-c">C</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockHead,
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

    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockHead,
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

    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockHead,
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

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockHead,
          classNames: "custom-head",
          children: [{ block: BemTestChild }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom('[data-block-name="head"]')
      .exists("has data-block-name attribute");
    assert.dom(".custom-head").exists("has custom class");
  });

  test("works nested inside a group", async function (assert) {
    @block("nested-head-a")
    class NestedHeadA extends Component {
      <template>
        <div class="nested-a">A</div>
      </template>
    }

    @block("nested-head-b")
    class NestedHeadB extends Component {
      <template>
        <div class="nested-b">B</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockGroup,
          id: "outer",
          children: [
            {
              block: BlockHead,
              children: [{ block: NestedHeadA }, { block: NestedHeadB }],
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert
      .dom(".homepage-blocks__block-container--outer")
      .exists("group renders with BEM modifier");
    assert.dom(".nested-a").exists("head renders first child");
    assert.dom(".nested-b").doesNotExist("head does not render second child");
  });

  test("passes args to the rendered child", async function (assert) {
    @block("args-head-child", { args: { message: { type: "string" } } })
    class ArgsHeadChild extends Component {
      <template>
        <div class="args-child">{{@message}}</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockHead,
          children: [
            {
              block: ArgsHeadChild,
              args: { message: "Hello from head" },
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".args-child").hasText("Hello from head");
  });

  test("@outletName is accessible in the rendered child", async function (assert) {
    @block("outlet-name-head-child")
    class OutletNameHeadChild extends Component {
      <template>
        <div
          class="outlet-display"
          data-outlet={{@outletName}}
        >{{@outletName}}</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: BlockHead,
          children: [{ block: OutletNameHeadChild }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    const display = document.querySelector(".outlet-display");
    assert.strictEqual(display.getAttribute("data-outlet"), "sidebar-blocks");
    assert.strictEqual(display.textContent.trim(), "sidebar-blocks");
  });

  test("shows ghosts for children that failed conditions in debug mode", async function (assert) {
    const capturedGhosts = setupGhostCapture();

    @block("ghost-fail-child")
    class GhostFailChild extends Component {
      <template>
        <div class="fail-child">Should be ghost</div>
      </template>
    }

    @block("ghost-pass-child")
    class GhostPassChild extends Component {
      <template>
        <div class="pass-child">Rendered</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockHead,
          children: [
            {
              block: GhostFailChild,
              conditions: { type: "user", admin: true },
            },
            { block: GhostPassChild },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".pass-child").exists("passing child renders");
    assert
      .dom('.ghost-block[data-name="ghost-fail-child"]')
      .exists("failed child shows as ghost");
    assert
      .dom(`[data-type="${FAILURE_TYPE.CONDITION_FAILED}"]`)
      .exists("ghost has correct failure type");

    const failedGhost = capturedGhosts.find(
      (g) => g.name === "ghost-fail-child"
    );
    assert.strictEqual(
      failedGhost?.failureType,
      FAILURE_TYPE.CONDITION_FAILED,
      "captured ghost has CONDITION_FAILED type"
    );

    // Verify order: ghost should appear before the rendered child
    const headContainer = document.querySelector('[data-block-name="head"]');
    const children = [...headContainer.children];
    const ghostIndex = children.findIndex((el) =>
      el.matches('.ghost-block[data-name="ghost-fail-child"]')
    );
    const passIndex = children.findIndex((el) =>
      el.querySelector(".pass-child")
    );
    assert.true(
      ghostIndex < passIndex,
      "ghost appears before rendered child in DOM order"
    );
  });

  test("shows ghosts for children hidden by priority in debug mode", async function (assert) {
    const capturedGhosts = setupGhostCapture();

    @block("priority-first")
    class PriorityFirst extends Component {
      <template>
        <div class="priority-first">First</div>
      </template>
    }

    @block("priority-second")
    class PrioritySecond extends Component {
      <template>
        <div class="priority-second">Second</div>
      </template>
    }

    @block("priority-third")
    class PriorityThird extends Component {
      <template>
        <div class="priority-third">Third</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockHead,
          children: [
            { block: PriorityFirst },
            { block: PrioritySecond },
            { block: PriorityThird },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".priority-first").exists("first child renders");
    assert.dom(".priority-second").doesNotExist("second child does not render");
    assert.dom(".priority-third").doesNotExist("third child does not render");

    assert
      .dom('.ghost-block[data-name="priority-second"]')
      .exists("second child shows as ghost");
    assert
      .dom('.ghost-block[data-name="priority-third"]')
      .exists("third child shows as ghost");

    const hiddenGhosts = capturedGhosts.filter(
      (g) => g.name === "priority-second" || g.name === "priority-third"
    );
    assert.strictEqual(
      hiddenGhosts.length,
      2,
      "two children hidden by priority"
    );
    assert.true(
      hiddenGhosts.every(
        (g) =>
          g.failureReason ===
          i18n("js.blocks.ghost_reasons.head_hidden_tail_hint")
      ),
      "ghosts have hidden-by-priority reason"
    );

    // Verify order: first < second ghost < third ghost
    const headContainer = document.querySelector('[data-block-name="head"]');
    const children = [...headContainer.children];
    const firstIndex = children.findIndex((el) =>
      el.querySelector(".priority-first")
    );
    const secondGhostIndex = children.findIndex((el) =>
      el.matches('.ghost-block[data-name="priority-second"]')
    );
    const thirdGhostIndex = children.findIndex((el) =>
      el.matches('.ghost-block[data-name="priority-third"]')
    );
    assert.true(
      firstIndex < secondGhostIndex,
      "rendered child appears before second ghost"
    );
    assert.true(
      secondGhostIndex < thirdGhostIndex,
      "second ghost appears before third ghost"
    );
  });

  test("no ghosts rendered when debug mode is disabled", async function (assert) {
    // When visual overlay is disabled, ghosts should not be rendered even if
    // BLOCK_DEBUG callback is set. The blocks service's showGhosts getter
    // controls whether head block renders ghosts for hidden children.
    setupGhostCapture({ enabled: false });

    @block("no-ghost-first")
    class NoGhostFirst extends Component {
      <template>
        <div class="no-ghost-first">First</div>
      </template>
    }

    @block("no-ghost-second")
    class NoGhostSecond extends Component {
      <template>
        <div class="no-ghost-second">Second</div>
      </template>
    }

    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: BlockHead,
          children: [{ block: NoGhostFirst }, { block: NoGhostSecond }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    assert.dom(".no-ghost-first").exists("first child renders");
    assert.dom(".no-ghost-second").doesNotExist("second child does not render");
    assert
      .dom(".ghost-block")
      .doesNotExist("no ghost blocks rendered when overlay disabled");
  });
});
