import { click, fillIn, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ReorderableListBasicExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/basic";
import ReorderableListCreateExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/create";
import ReorderableListCrossListExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/cross-list";
import ReorderableListEditableExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/editable";
import ReorderableListPoliciesExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/policies";
import ReorderableListTableExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/table";
import ReorderableListTogglesExample from "discourse/plugins/styleguide/discourse/components/examples/molecules/reorderable-list/toggles";

module(
  "Styleguide | Integration | reorderable-list examples",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the basic example renders and commits a menu move", async function (assert) {
      await render(
        <template><DMenus /><ReorderableListBasicExample /></template>
      );

      assert
        .dom(".d-reorderable-list__row")
        .exists({ count: 4 }, "every fixture row renders");

      await click("[data-reorderable-key='inbox'] .d-reorderable-list__handle");
      assert
        .dom(".d-reorderable-list__move-item")
        .exists(
          { count: 2 },
          "the handle opens its move menu, holding what the first row can reach"
        );

      await click(".d-reorderable-list__move-item.--down");
      assert.deepEqual(
        findAll(".d-reorderable-list__row")
          .map((row) => row.dataset.reorderableKey)
          .slice(0, 2),
        ["starred", "inbox"],
        "the chosen destination applies the proposed order"
      );
    });

    test("the policies example subtracts the control each policy refuses", async function (assert) {
      await render(
        <template><DMenus /><ReorderableListPoliciesExample /></template>
      );

      assert
        .dom(
          "[data-reorderable-key='announcements'] .d-reorderable-list__handle"
        )
        .doesNotExist("a pinned row renders no handle");
      assert
        .dom("[data-reorderable-key='bookmarks'] .d-reorderable-list__handle")
        .doesNotExist("at either end of the list");
      assert
        .dom("[data-reorderable-key='categories'] .d-reorderable-list__remove")
        .doesNotExist(
          "and a protected row renders no remove control rather than a dead one"
        );
      assert
        .dom("[data-reorderable-key='categories'] .d-reorderable-list__handle")
        .exists("while still being movable, since the policies are separate");
      assert
        .dom(".d-reorderable-list__row:last-child")
        .hasAttribute(
          "data-reorderable-key",
          "bookmarks",
          "the bottom-pinned row keeps the last slot"
        );
    });

    test("the basic example gives every row a reachable handle", async function (assert) {
      await render(
        <template><DMenus /><ReorderableListBasicExample /></template>
      );

      assert
        .dom("button.d-reorderable-list__handle")
        .exists({ count: 4 }, "every row renders a real handle button");
      assert
        .dom("button.d-reorderable-list__handle[tabindex='-1']")
        .doesNotExist("none is held out of the tab sequence");
      assert
        .dom(".d-reorderable-list__row[tabindex]")
        .doesNotExist("and the row itself is not a focus target");
    });

    test("the cross-list example renders both grouped members", async function (assert) {
      await render(
        <template><DMenus /><ReorderableListCrossListExample /></template>
      );

      assert
        .dom(".d-reorderable-list")
        .exists({ count: 2 }, "both member lists render");
    });

    test("the toggles example moves rows between the order and the static block", async function (assert) {
      await render(
        <template><DMenus /><ReorderableListTogglesExample /></template>
      );

      assert
        .dom(".d-reorderable-list__row .d-reorderable-list__handle")
        .exists({ count: 3 }, "the enabled rows carry reorder controls");
      assert
        .dom("[data-reorderable-key='backups'] .d-reorderable-list__handle")
        .doesNotExist("a static row carries no controls");

      await click(
        "[data-reorderable-key='backups'] .d-toggle-switch__checkbox"
      );
      assert
        .dom("[data-reorderable-key='backups'] .d-reorderable-list__handle")
        .exists("toggling a static row on makes it reorderable");

      await click(
        "[data-reorderable-key='summary'] .d-toggle-switch__checkbox"
      );
      assert
        .dom("[data-reorderable-key='summary'] .d-reorderable-list__handle")
        .doesNotExist("toggling an enabled row off drops it out of the order");
    });

    test("the editable example keeps typing in the input and removes rows", async function (assert) {
      await render(
        <template><DMenus /><ReorderableListEditableExample /></template>
      );

      await fillIn(
        "[data-reorderable-key='rules'] input",
        "Read the guidelines"
      );
      assert
        .dom("[data-reorderable-key='rules'] input")
        .hasValue("Read the guidelines", "typing lands in the row's input");

      await click("[data-reorderable-key='rules'] .d-reorderable-list__remove");
      assert
        .dom("[data-reorderable-key='rules']")
        .doesNotExist("the remove button deletes the row");
      assert
        .dom(".d-reorderable-list__row")
        .exists({ count: 2 }, "the remaining rows survive");
    });

    test("the table example reorders native rows with manual cell controls", async function (assert) {
      await render(
        <template><DMenus /><ReorderableListTableExample /></template>
      );

      assert
        .dom("tbody.d-reorderable-list tr.d-reorderable-list__row")
        .exists({ count: 3 }, "the list renders native table rows");
      assert
        .dom(
          "tr[data-reorderable-key='name'] td:first-child .d-reorderable-list__handle"
        )
        .exists("the controls sit in the first cell");

      await click(
        "tr[data-reorderable-key='name'] .d-reorderable-list__handle"
      );
      await click(".d-reorderable-list__move-item.--down");
      assert.deepEqual(
        findAll("tr.d-reorderable-list__row").map(
          (row) => row.dataset.reorderableKey
        ),
        ["location", "name", "website"],
        "the chosen destination reorders the table rows"
      );
    });

    test("the create example renders the create affordance", async function (assert) {
      await render(
        <template><DMenus /><ReorderableListCreateExample /></template>
      );

      assert
        .dom(".d-reorderable-list__create-input")
        .exists("the create input renders");
    });
  }
);
