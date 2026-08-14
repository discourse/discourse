import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ReorderableListBasicExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/basic";
import ReorderableListCreateExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/create";
import ReorderableListCrossListExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/cross-list";
import ReorderableListGrabExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/grab";
import ReorderableListPoliciesExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/policies";

module(
  "Styleguide | Integration | reorderable-list examples",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the basic example renders and commits an arrow move", async function (assert) {
      await render(<template><ReorderableListBasicExample /></template>);

      assert
        .dom(".d-reorderable-list__row")
        .exists({ count: 4 }, "every fixture row renders");
      assert
        .dom(
          "[data-reorderable-key='inbox'] .d-reorder-buttons__button:last-child"
        )
        .exists("the arrow pair renders");

      await click(
        "[data-reorderable-key='inbox'] .d-reorder-buttons__button:last-child"
      );
      assert
        .dom(".d-reorderable-list__row:nth-child(2)")
        .hasAttribute(
          "data-reorderable-key",
          "inbox",
          "the arrow press applies the proposed order"
        );
    });

    test("the policies example freezes its pinned row", async function (assert) {
      await render(<template><ReorderableListPoliciesExample /></template>);

      assert
        .dom("[data-reorderable-key='pinned'] .d-reorderable-list__handle")
        .doesNotExist("the pinned row renders no controls");
      assert
        .dom(".d-reorderable-list")
        .hasClass("--reveal-controls", "reveal visibility marks the list");
    });

    test("the grab example renders grab buttons and no arrows", async function (assert) {
      await render(<template><ReorderableListGrabExample /></template>);

      assert
        .dom("button.d-reorderable-list__handle.--grab")
        .exists({ count: 4 }, "every row renders a grab button");
      assert
        .dom(".d-reorder-buttons")
        .doesNotExist("grab mode renders no arrow pairs");
    });

    test("the cross-list example renders both grouped members", async function (assert) {
      await render(<template><ReorderableListCrossListExample /></template>);

      assert
        .dom(".d-reorderable-list")
        .exists({ count: 2 }, "both member lists render");
    });

    test("the create example renders the create affordance", async function (assert) {
      await render(<template><ReorderableListCreateExample /></template>);

      assert
        .dom(".d-reorderable-list__create-input")
        .exists("the create input renders");
    });
  }
);
