import { getOwner } from "@ember/owner";
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BoardsPage from "discourse/plugins/boards/discourse/components/boards-page";
import BoardsFabricators from "discourse/plugins/boards/discourse/lib/fabricators";

module("Integration | Component | BoardsPage", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    const fabricators = new BoardsFabricators(getOwner(this));
    this.boards = [
      fabricators.board({ id: 1, name: "Current work" }),
      Object.assign(fabricators.board({ id: 2, name: "Past work" }), {
        archived: true,
      }),
    ];
  });

  test("defaults to open and combines archive status with search", async function (assert) {
    await render(<template><BoardsPage @boards={{this.boards}} /></template>);
    assert
      .dom(".d-filter-controls__dropdown")
      .hasValue("open", "Open is selected initially");
    assert
      .dom(".discourse-boards-board-card__name")
      .hasText("Current work", "only open boards appear initially");
    assert
      .dom(".discourse-boards-board-card")
      .exists({ count: 1 }, "archived boards are excluded");

    await fillIn(".d-filter-controls__dropdown", "all");
    assert
      .dom(".discourse-boards-board-card")
      .exists({ count: 2 }, "All includes both states");
    await fillIn(".d-filter-controls__input", "Past");
    assert
      .dom(".discourse-boards-board-card__name")
      .hasText("Past work", "search applies to All");
    await fillIn(".d-filter-controls__dropdown", "open");
    assert
      .dom(".discourse-boards-board-card")
      .doesNotExist("search cannot reveal an archived board under Open");
    assert
      .dom(".d-filter-controls__no-results")
      .exists("empty filtered results have an explanation");
    await fillIn(".d-filter-controls__dropdown", "archived");
    assert
      .dom(".discourse-boards-board-card__name")
      .hasText("Past work", "Archived combines with search");
  });

  test("keeps the status filter available when every board is archived", async function (assert) {
    this.boards = [this.boards[1]];
    await render(<template><BoardsPage @boards={{this.boards}} /></template>);
    assert
      .dom(".d-filter-controls__no-results")
      .exists("Open explains the empty result");
    await fillIn(".d-filter-controls__dropdown", "archived");
    assert
      .dom(".discourse-boards-board-card__name")
      .hasText("Past work", "the archived board is reachable");
  });
});
