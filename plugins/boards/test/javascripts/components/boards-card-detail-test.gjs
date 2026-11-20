import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import BoardsCardDetail from "discourse/plugins/boards/discourse/components/modal/boards-card-detail";
import Board from "discourse/plugins/boards/discourse/models/board";

module("Integration | Component | BoardsCardDetail", function (hooks) {
  setupRenderingTest(hooks);

  test("assignment is disabled when the board cannot be written to", async function (assert) {
    this.siteSettings.assign_enabled = true;
    pretender.post("/boards/api/boards/1/cards/2/view", () => response({}));
    this.model = {
      board: Board.create({ archived: true, can_write: true }),
      card: {
        id: 2,
        board_id: 1,
        title: "Test card",
        assigned_to: { username: "martin" },
      },
    };

    await render(
      <template>
        <BoardsCardDetail @inline={{true}} @model={{this.model}} />
      </template>
    );

    assert
      .dom(".email-group-user-chooser")
      .hasClass("is-disabled", "archived card assignment is disabled");

    this.model.board.archived = false;
    await settled();

    assert
      .dom(".email-group-user-chooser")
      .doesNotHaveClass("is-disabled", "writable cards allow assignment");

    this.model.board.can_write = false;
    await settled();

    assert
      .dom(".email-group-user-chooser")
      .hasClass("is-disabled", "view-only card assignment is disabled");
  });
});
