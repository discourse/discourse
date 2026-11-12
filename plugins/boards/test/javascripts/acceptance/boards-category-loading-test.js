import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import PermissionType from "discourse/models/permission-type";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

const CATEGORY_ID = 12345;
const CATEGORY_NAME = "Unvisited category";
const BOARD_ID = 1;
const COLUMN_ID = 10;
const CARD_ID = 101;
const category = {
  id: CATEGORY_ID,
  name: CATEGORY_NAME,
  slug: "unvisited-category",
  color: "0088CC",
  text_color: "FFFFFF",
  permission: PermissionType.FULL,
};

acceptance("Boards category loading", function (needs) {
  needs.user({ can_manage_boards: true });
  needs.settings({ boards_enabled: true });
  needs.site({ lazy_load_categories: true });

  needs.hooks.beforeEach(function () {
    this.card = {
      id: CARD_ID,
      board_id: BOARD_ID,
      column_id: COLUMN_ID,
      card_type: "topic",
      position: 0,
      topic_id: 42,
      topic: {
        id: 42,
        title: "Unvisited topic",
        slug: "unvisited-topic",
        category_id: CATEGORY_ID,
      },
    };
    this.column = {
      id: COLUMN_ID,
      title: "Todo",
      default_sort: "priority",
      cards: [
        {
          ...this.card,
          id: CARD_ID + 1,
          topic_id: 43,
          position: 1,
          topic: { ...this.card.topic, id: 43, category_id: 1 },
        },
      ],
    };
    this.board = {
      id: BOARD_ID,
      name: "Category audit",
      slug: "category-audit",
      can_write: true,
      can_manage: true,
      category_ids: [],
      tag_names: [],
      columns: [this.column],
    };
    pretender.get("/categories/find", (request) =>
      response({
        categories: request.queryParams.ids.map((id) =>
          Number(id) === CATEGORY_ID
            ? category
            : {
                ...category,
                id: Number(id),
                name: "Uncategorized",
                slug: "uncategorized",
              }
        ),
      })
    );
    pretender.get(`/boards/api/boards/${BOARD_ID}.json`, () =>
      response({ board: this.board, columns: [this.column] })
    );
  });

  test("incoming topic cards load their categories", async function (assert) {
    await visit(`/boards/category-audit/${BOARD_ID}`);
    await publishToMessageBus(`/boards/${BOARD_ID}`, {
      type: "card_created",
      card: this.card,
    });

    assert
      .dom(`[data-card-id="${CARD_ID}"] .discourse-boards-card__category`)
      .includesText(CATEGORY_NAME, "the incoming card loads its category");
  });

  test("board refresh loads newly configured categories", async function (assert) {
    await visit(`/boards/category-audit/${BOARD_ID}`);
    this.board.category_ids = [CATEGORY_ID];
    await publishToMessageBus(`/boards/${BOARD_ID}`, {
      type: "board_updated",
    });

    assert
      .dom(".discourse-boards-board-viewer__constraint")
      .includesText(
        CATEGORY_NAME,
        "the refreshed board loads its new constraint"
      );
  });
});
