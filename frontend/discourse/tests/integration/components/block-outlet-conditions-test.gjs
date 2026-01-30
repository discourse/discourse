import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, { block } from "discourse/blocks/block-outlet";
import BlockGroup from "discourse/blocks/builtin/block-group";
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  registerBlock,
  registerConditionType,
  withTestBlockRegistration,
  withTestConditionRegistration,
} from "discourse/tests/helpers/block-testing";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

/* Test condition classes - defined at module scope to use with decorator */

@blockCondition({ type: "always-true", args: {} })
class BlockAlwaysTrueCondition extends BlockCondition {
  evaluate() {
    return true;
  }
}

@blockCondition({ type: "always-false", args: {} })
class BlockAlwaysFalseCondition extends BlockCondition {
  evaluate() {
    return false;
  }
}

module("Integration | Blocks | BlockOutlet | Conditions", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    // Register test conditions for each test (registries are reset between tests)
    withTestConditionRegistration(() => {
      registerConditionType(BlockAlwaysTrueCondition);
      registerConditionType(BlockAlwaysFalseCondition);
    });
  });

  test("renders block when no conditions specified", async function (assert) {
    @block("no-condition-block")
    class NoConditionBlock extends Component {
      <template>
        <div class="no-condition">No Condition</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(NoConditionBlock));
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [{ block: NoConditionBlock }])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".no-condition").exists();
  });

  test("renders block when condition passes", async function (assert) {
    @block("passing-condition-block")
    class PassingConditionBlock extends Component {
      <template>
        <div class="passing-condition">Passes</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(PassingConditionBlock));
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: PassingConditionBlock,
          conditions: { type: "always-true" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".passing-condition").exists();
  });

  test("hides block when condition fails", async function (assert) {
    @block("failing-condition-block")
    class FailingConditionBlock extends Component {
      <template>
        <div class="failing-condition">Fails</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(FailingConditionBlock));
    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: FailingConditionBlock,
          conditions: { type: "always-false" },
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    assert.dom(".failing-condition").doesNotExist();
  });

  test("AND logic: hides if any condition fails", async function (assert) {
    @block("and-logic-block")
    class AndLogicBlock extends Component {
      <template>
        <div class="and-logic">AND Logic</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(AndLogicBlock));
    withPluginApi((api) =>
      api.renderBlocks("main-outlet-blocks", [
        {
          block: AndLogicBlock,
          conditions: [{ type: "always-true" }, { type: "always-false" }],
        },
      ])
    );

    await render(
      <template><BlockOutlet @name="main-outlet-blocks" /></template>
    );

    assert.dom(".and-logic").doesNotExist();
  });

  test("AND logic: renders when all conditions pass", async function (assert) {
    @block("all-pass-block")
    class AllPassBlock extends Component {
      <template>
        <div class="all-pass">All Pass</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(AllPassBlock));
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: AllPassBlock,
          conditions: [{ type: "always-true" }, { type: "always-true" }],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".all-pass").exists();
  });

  test("OR logic: renders when any condition passes", async function (assert) {
    @block("or-logic-pass-block")
    class OrLogicPassBlock extends Component {
      <template>
        <div class="or-logic-pass">OR Logic Pass</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(OrLogicPassBlock));
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: OrLogicPassBlock,
          conditions: {
            any: [{ type: "always-false" }, { type: "always-true" }],
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".or-logic-pass").exists();
  });

  test("OR logic: hides when all conditions fail", async function (assert) {
    @block("or-logic-fail-block")
    class OrLogicFailBlock extends Component {
      <template>
        <div class="or-logic-fail">OR Logic Fail</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(OrLogicFailBlock));
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: OrLogicFailBlock,
          conditions: {
            any: [{ type: "always-false" }, { type: "always-false" }],
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".or-logic-fail").doesNotExist();
  });

  test("NOT logic: inverts true to false", async function (assert) {
    @block("not-true-block")
    class NotTrueBlock extends Component {
      <template>
        <div class="not-true">NOT True</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(NotTrueBlock));
    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: NotTrueBlock,
          conditions: { not: { type: "always-true" } },
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    assert.dom(".not-true").doesNotExist();
  });

  test("NOT logic: inverts false to true", async function (assert) {
    @block("not-false-block")
    class NotFalseBlock extends Component {
      <template>
        <div class="not-false">NOT False</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(NotFalseBlock));
    withPluginApi((api) =>
      api.renderBlocks("main-outlet-blocks", [
        {
          block: NotFalseBlock,
          conditions: { not: { type: "always-false" } },
        },
      ])
    );

    await render(
      <template><BlockOutlet @name="main-outlet-blocks" /></template>
    );

    assert.dom(".not-false").exists();
  });

  test("filters nested children based on conditions", async function (assert) {
    @block("nested-visible")
    class NestedVisibleBlock extends Component {
      <template>
        <div class="nested-visible">Visible</div>
      </template>
    }

    @block("nested-hidden")
    class NestedHiddenBlock extends Component {
      <template>
        <div class="nested-hidden">Hidden</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(NestedVisibleBlock);
      registerBlock(NestedHiddenBlock);
    });
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockGroup,
          args: { name: "test-group" },
          children: [
            {
              block: NestedVisibleBlock,
              conditions: { type: "always-true" },
            },
            {
              block: NestedHiddenBlock,
              conditions: { type: "always-false" },
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".nested-visible").exists();
    assert.dom(".nested-hidden").doesNotExist();
  });

  test("multiple blocks with mixed conditions", async function (assert) {
    @block("mixed-visible-1")
    class MixedVisible1 extends Component {
      <template>
        <div class="mixed-visible-1">Visible 1</div>
      </template>
    }

    @block("mixed-visible-2")
    class MixedVisible2 extends Component {
      <template>
        <div class="mixed-visible-2">Visible 2</div>
      </template>
    }

    @block("mixed-hidden")
    class MixedHidden extends Component {
      <template>
        <div class="mixed-hidden">Hidden</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(MixedVisible1);
      registerBlock(MixedVisible2);
      registerBlock(MixedHidden);
    });
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        { block: MixedVisible1, conditions: { type: "always-true" } },
        { block: MixedHidden, conditions: { type: "always-false" } },
        { block: MixedVisible2 },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".mixed-visible-1").exists();
    assert.dom(".mixed-visible-2").exists();
    assert.dom(".mixed-hidden").doesNotExist();
  });

  test("complex nested conditions: NOT within OR renders when inner condition is false", async function (assert) {
    @block("not-within-or-block")
    class NotWithinOrBlock extends Component {
      <template>
        <div class="not-within-or">NOT within OR</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(NotWithinOrBlock));
    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: NotWithinOrBlock,
          conditions: {
            any: [{ type: "always-false" }, { not: { type: "always-false" } }],
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    assert.dom(".not-within-or").exists();
  });

  test("complex nested conditions: OR within AND hides when AND fails", async function (assert) {
    @block("or-within-and-block")
    class OrWithinAndBlock extends Component {
      <template>
        <div class="or-within-and">OR within AND</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(OrWithinAndBlock));
    withPluginApi((api) =>
      api.renderBlocks("main-outlet-blocks", [
        {
          block: OrWithinAndBlock,
          conditions: [
            { any: [{ type: "always-true" }, { type: "always-false" }] },
            { type: "always-false" },
          ],
        },
      ])
    );

    await render(
      <template><BlockOutlet @name="main-outlet-blocks" /></template>
    );

    assert.dom(".or-within-and").doesNotExist();
  });

  test("complex nested conditions: OR within AND renders when all pass", async function (assert) {
    @block("or-within-and-pass-block")
    class OrWithinAndPassBlock extends Component {
      <template>
        <div class="or-within-and-pass">OR within AND Pass</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(OrWithinAndPassBlock));
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: OrWithinAndPassBlock,
          conditions: [
            { any: [{ type: "always-false" }, { type: "always-true" }] },
            { type: "always-true" },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".or-within-and-pass").exists();
  });

  test("complex nested conditions: deeply nested NOT within OR within AND", async function (assert) {
    @block("deep-nested-block")
    class DeepNestedBlock extends Component {
      <template>
        <div class="deep-nested">Deep Nested</div>
      </template>
    }

    withTestBlockRegistration(() => registerBlock(DeepNestedBlock));
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: DeepNestedBlock,
          conditions: [
            {
              any: [
                { not: { type: "always-true" } },
                { not: { type: "always-false" } },
              ],
            },
            { type: "always-true" },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".deep-nested").exists();
  });

  test("container with all children failing conditions does not render", async function (assert) {
    @block("child-hidden-1")
    class ChildHidden1 extends Component {
      <template>
        <div class="child-hidden-1">Hidden 1</div>
      </template>
    }

    @block("child-hidden-2")
    class ChildHidden2 extends Component {
      <template>
        <div class="child-hidden-2">Hidden 2</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(ChildHidden1);
      registerBlock(ChildHidden2);
    });
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockGroup,
          args: { name: "admin-only" },
          classNames: "admin-only-group",
          children: [
            {
              block: ChildHidden1,
              conditions: { type: "always-false" },
            },
            {
              block: ChildHidden2,
              conditions: { type: "always-false" },
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // Container should not render because no children are visible
    assert.dom(".admin-only-group").doesNotExist();
    assert.dom(".child-hidden-1").doesNotExist();
    assert.dom(".child-hidden-2").doesNotExist();
  });

  test("container with at least one visible child renders", async function (assert) {
    @block("child-visible-container")
    class ChildVisibleContainer extends Component {
      <template>
        <div class="child-visible-container">Visible</div>
      </template>
    }

    @block("child-hidden-container")
    class ChildHiddenContainer extends Component {
      <template>
        <div class="child-hidden-container">Hidden</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(ChildVisibleContainer);
      registerBlock(ChildHiddenContainer);
    });
    withPluginApi((api) =>
      api.renderBlocks("sidebar-blocks", [
        {
          block: BlockGroup,
          args: { name: "mixed" },
          classNames: "mixed-group",
          children: [
            {
              block: ChildVisibleContainer,
              conditions: { type: "always-true" },
            },
            {
              block: ChildHiddenContainer,
              conditions: { type: "always-false" },
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

    // Container should render because at least one child is visible
    assert.dom(".mixed-group").exists();
    assert.dom(".child-visible-container").exists();
    assert.dom(".child-hidden-container").doesNotExist();
  });

  test("nested containers: inner container without visible children hides outer container", async function (assert) {
    @block("deeply-hidden-child")
    class DeeplyHiddenChild extends Component {
      <template>
        <div class="deeply-hidden-child">Hidden</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(DeeplyHiddenChild);
    });
    withPluginApi((api) =>
      api.renderBlocks("main-outlet-blocks", [
        {
          block: BlockGroup,
          args: { name: "outer" },
          classNames: "outer-group",
          children: [
            {
              block: BlockGroup,
              args: { name: "inner" },
              classNames: "inner-group",
              children: [
                {
                  block: DeeplyHiddenChild,
                  conditions: { type: "always-false" },
                },
              ],
            },
          ],
        },
      ])
    );

    await render(
      <template><BlockOutlet @name="main-outlet-blocks" /></template>
    );

    // Both containers should not render because the deepest child fails
    assert.dom(".outer-group").doesNotExist();
    assert.dom(".inner-group").doesNotExist();
    assert.dom(".deeply-hidden-child").doesNotExist();
  });

  test("nested containers: outer renders when inner has visible children", async function (assert) {
    @block("deeply-visible-child")
    class DeeplyVisibleChild extends Component {
      <template>
        <div class="deeply-visible-child">Visible</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(DeeplyVisibleChild);
    });
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: BlockGroup,
          args: { name: "outer-visible" },
          classNames: "outer-visible-group",
          children: [
            {
              block: BlockGroup,
              args: { name: "inner-visible" },
              classNames: "inner-visible-group",
              children: [
                {
                  block: DeeplyVisibleChild,
                  conditions: { type: "always-true" },
                },
              ],
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    // Both containers should render because the deepest child is visible
    assert.dom(".outer-visible-group").exists();
    assert.dom(".inner-visible-group").exists();
    assert.dom(".deeply-visible-child").exists();
  });

  test("container with own failing condition does not render even with visible children", async function (assert) {
    @block("child-would-be-visible")
    class ChildWouldBeVisible extends Component {
      <template>
        <div class="child-would-be-visible">Would be visible</div>
      </template>
    }

    withTestBlockRegistration(() => {
      registerBlock(ChildWouldBeVisible);
    });
    withPluginApi((api) =>
      api.renderBlocks("homepage-blocks", [
        {
          block: BlockGroup,
          args: { name: "failing" },
          classNames: "failing-container",
          conditions: { type: "always-false" },
          children: [
            {
              block: ChildWouldBeVisible,
              conditions: { type: "always-true" },
            },
          ],
        },
      ])
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    // Container should not render because its own condition fails
    assert.dom(".failing-container").doesNotExist();
    assert.dom(".child-would-be-visible").doesNotExist();
  });
});
