import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockGroup from "discourse/blocks/block-group";
import { BlockCondition } from "discourse/blocks/conditions";
import BlockOutlet, {
  block,
  renderBlocks,
} from "discourse/components/block-outlet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

let testOwner;

module("Integration | Blocks | BlockOutlet | Conditions", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    testOwner = getOwner(this);

    const blocks = testOwner.lookup("service:blocks");

    class BlockAlwaysTrueCondition extends BlockCondition {
      static type = "always-true";

      evaluate() {
        return true;
      }
    }

    class BlockAlwaysFalseCondition extends BlockCondition {
      static type = "always-false";

      evaluate() {
        return false;
      }
    }

    if (!blocks.hasConditionType("always-true")) {
      blocks.registerConditionType(BlockAlwaysTrueCondition);
    }
    if (!blocks.hasConditionType("always-false")) {
      blocks.registerConditionType(BlockAlwaysFalseCondition);
    }
  });

  test("renders block when no conditions specified", async function (assert) {
    @block("no-condition-block")
    class NoConditionBlock extends Component {
      <template>
        <div class="no-condition">No Condition</div>
      </template>
    }

    renderBlocks("hero-blocks", [{ block: NoConditionBlock }], testOwner);

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

    renderBlocks(
      "homepage-blocks",
      [
        {
          block: PassingConditionBlock,
          conditions: { type: "always-true" },
        },
      ],
      testOwner
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

    renderBlocks(
      "sidebar-blocks",
      [
        {
          block: FailingConditionBlock,
          conditions: { type: "always-false" },
        },
      ],
      testOwner
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

    renderBlocks(
      "main-outlet-blocks",
      [
        {
          block: AndLogicBlock,
          conditions: [{ type: "always-true" }, { type: "always-false" }],
        },
      ],
      testOwner
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

    renderBlocks(
      "header-blocks",
      [
        {
          block: AllPassBlock,
          conditions: [{ type: "always-true" }, { type: "always-true" }],
        },
      ],
      testOwner
    );

    await render(<template><BlockOutlet @name="header-blocks" /></template>);

    assert.dom(".all-pass").exists();
  });

  test("OR logic: renders when any condition passes", async function (assert) {
    @block("or-logic-pass-block")
    class OrLogicPassBlock extends Component {
      <template>
        <div class="or-logic-pass">OR Logic Pass</div>
      </template>
    }

    renderBlocks(
      "hero-blocks",
      [
        {
          block: OrLogicPassBlock,
          conditions: {
            any: [{ type: "always-false" }, { type: "always-true" }],
          },
        },
      ],
      testOwner
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

    renderBlocks(
      "homepage-blocks",
      [
        {
          block: OrLogicFailBlock,
          conditions: {
            any: [{ type: "always-false" }, { type: "always-false" }],
          },
        },
      ],
      testOwner
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

    renderBlocks(
      "sidebar-blocks",
      [
        {
          block: NotTrueBlock,
          conditions: { not: { type: "always-true" } },
        },
      ],
      testOwner
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

    renderBlocks(
      "main-outlet-blocks",
      [
        {
          block: NotFalseBlock,
          conditions: { not: { type: "always-false" } },
        },
      ],
      testOwner
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

    renderBlocks(
      "header-blocks",
      [
        {
          block: BlockGroup,
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
      ],
      testOwner
    );

    await render(<template><BlockOutlet @name="header-blocks" /></template>);

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

    renderBlocks(
      "hero-blocks",
      [
        { block: MixedVisible1, conditions: { type: "always-true" } },
        { block: MixedHidden, conditions: { type: "always-false" } },
        { block: MixedVisible2 },
      ],
      testOwner
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

    renderBlocks(
      "sidebar-blocks",
      [
        {
          block: NotWithinOrBlock,
          conditions: {
            any: [{ type: "always-false" }, { not: { type: "always-false" } }],
          },
        },
      ],
      testOwner
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

    renderBlocks(
      "main-outlet-blocks",
      [
        {
          block: OrWithinAndBlock,
          conditions: [
            { any: [{ type: "always-true" }, { type: "always-false" }] },
            { type: "always-false" },
          ],
        },
      ],
      testOwner
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

    renderBlocks(
      "header-blocks",
      [
        {
          block: OrWithinAndPassBlock,
          conditions: [
            { any: [{ type: "always-false" }, { type: "always-true" }] },
            { type: "always-true" },
          ],
        },
      ],
      testOwner
    );

    await render(<template><BlockOutlet @name="header-blocks" /></template>);

    assert.dom(".or-within-and-pass").exists();
  });

  test("complex nested conditions: deeply nested NOT within OR within AND", async function (assert) {
    @block("deep-nested-block")
    class DeepNestedBlock extends Component {
      <template>
        <div class="deep-nested">Deep Nested</div>
      </template>
    }

    renderBlocks(
      "homepage-blocks",
      [
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
      ],
      testOwner
    );

    await render(<template><BlockOutlet @name="homepage-blocks" /></template>);

    assert.dom(".deep-nested").exists();
  });
});
