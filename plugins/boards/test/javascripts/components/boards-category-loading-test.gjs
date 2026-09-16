import Service from "@ember/service";
import { click, getRootElement, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import PermissionType from "discourse/models/permission-type";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import BoardsBoardViewer from "discourse/plugins/boards/discourse/components/boards-board-viewer";
import BoardsCard from "discourse/plugins/boards/discourse/components/boards-card";
import BoardsPage from "discourse/plugins/boards/discourse/components/boards-page";
import BoardsBoardSettings from "discourse/plugins/boards/discourse/components/modal/boards-board-settings";
import BoardsConstraintFix from "discourse/plugins/boards/discourse/components/modal/boards-constraint-fix";
import BoardsTopicCardDetail from "discourse/plugins/boards/discourse/components/modal/boards-topic-card-detail";
import BoardsFabricators from "discourse/plugins/boards/discourse/lib/fabricators";
import Board from "discourse/plugins/boards/discourse/models/board";

const CATEGORY_ID = 12345;
const CATEGORY_NAME = "Unvisited category";
const ADDITIONAL_CATEGORY_ID = 12346;
const ADDITIONAL_CATEGORY_NAME = "Another category";
const category = {
  id: CATEGORY_ID,
  name: CATEGORY_NAME,
  slug: "unvisited-category",
  color: "0088CC",
  text_color: "FFFFFF",
  permission: PermissionType.FULL,
};
const additionalCategory = {
  ...category,
  id: ADDITIONAL_CATEGORY_ID,
  name: ADDITIONAL_CATEGORY_NAME,
  slug: "another-category",
};

module("Integration | Component | Boards category loading", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.site.set("lazy_load_categories", true);
    this.owner.lookup("service:modal").containerElement = getRootElement();
    this.fabricators = new BoardsFabricators(this.owner);
    this.board = this.fabricators.board();
    this.board.category_ids = [CATEGORY_ID];
    this.board.tag_names = [];
    this.column = this.fabricators.column();
    this.column.cards = [];
    this.model = { board: this.board, columns: [this.column] };
    this.onSave = sinon.spy();
    this.closeModal = sinon.spy();
    this.settingsModel = {
      board: this.board,
      isNew: false,
      onSave: this.onSave,
    };
    const messageBus = this.owner.lookup("service:message-bus");
    sinon.stub(messageBus, "subscribe");
    sinon.stub(messageBus, "unsubscribe");
    pretender.get("/categories/find", (request) =>
      response({
        categories: [category, additionalCategory].filter((item) =>
          request.queryParams.ids.includes(String(item.id))
        ),
      })
    );
    pretender.post("/categories/search", () =>
      response({ categories: [additionalCategory] })
    );
    pretender.post(
      `/boards/api/boards/${this.board.id}/constraint-preview`,
      () => response({ cards_to_remove: 0 })
    );
    pretender.post("/access-control/evaluate.json", () => response({}));
    pretender.get("/posts/by_number/42/1.json", () =>
      response({ cooked: "<p>Topic body</p>" })
    );
    this.topicCard = this.fabricators.card({
      board_id: this.board.id,
      column_id: this.column.id,
      topic: {
        id: 42,
        title: "Topic in an unvisited category",
        slug: "unvisited-topic",
        category_id: CATEGORY_ID,
      },
    });
  });

  for (const cacheState of ["cached", "uncached"]) {
    test(`constraint dialog names a ${cacheState} category`, async function (assert) {
      if (cacheState === "cached") {
        this.site.updateCategory(category);
      }

      this.constraintModel = {
        topic: { category_id: 1 },
        mismatches: {
          needsCategory: true,
          boardCategoryIds: [CATEGORY_ID],
        },
      };
      await render(
        <template>
          <BoardsConstraintFix @model={{this.constraintModel}} />
        </template>
      );

      assert.dom(`[data-category-id="${CATEGORY_ID}"]`).hasText(CATEGORY_NAME);
    });
  }

  test("a category omitted by the server does not prevent loading the board", async function (assert) {
    this.board.category_ids = [CATEGORY_ID, ADDITIONAL_CATEGORY_ID];
    pretender.get("/categories/find", () =>
      response({ categories: [category] })
    );

    const payload = await Board.createPayload(this.model);

    assert.strictEqual(
      payload.board.id,
      this.board.id,
      "the board remains available"
    );
  });

  test("boards list displays category constraints", async function (assert) {
    this.boards = [this.board];
    await render(<template><BoardsPage @boards={{this.boards}} /></template>);

    assert
      .dom(".discourse-boards-board-card__constraints")
      .includesText(CATEGORY_NAME, "the board constraint is visible");
  });

  test("board header displays category constraints", async function (assert) {
    await render(
      <template><BoardsBoardViewer @model={{this.model}} /></template>
    );

    assert
      .dom(".discourse-boards-board-viewer__constraint")
      .includesText(CATEGORY_NAME, "the board constraint is visible");
  });

  test("topic card displays its category", async function (assert) {
    await render(
      <template>
        <BoardsCard @board={{this.board}} @card={{this.topicCard}} />
      </template>
    );

    assert
      .dom(".discourse-boards-card__category")
      .includesText(CATEGORY_NAME, "the topic category is visible");
  });

  test("topic detail displays its category", async function (assert) {
    this.detailModel = { card: this.topicCard };
    pretender.post(
      `/boards/api/boards/${this.board.id}/cards/${this.topicCard.id}/view`,
      () => response({})
    );
    await render(
      <template><BoardsTopicCardDetail @model={{this.detailModel}} /></template>
    );

    assert
      .dom(".discourse-boards-topic-card-detail__meta")
      .includesText(CATEGORY_NAME, "the topic category is visible");
  });

  test("adding a category preserves existing category constraints", async function (assert) {
    await render(
      <template>
        <BoardsBoardSettings
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.settingsModel}}
        />
      </template>
    );
    assert.dom(".category-selector").includesText(CATEGORY_NAME);

    const selector = selectKit(".category-selector");
    await selector.expand();
    await selector.selectRowByValue(ADDITIONAL_CATEGORY_ID);
    await formKit().submit();

    assert.true(this.onSave.calledOnce, "settings are saved");
    assert.deepEqual(
      this.onSave.firstCall.args[0].category_ids,
      [CATEGORY_ID, ADDITIONAL_CATEGORY_ID],
      "adding a category retains the original constraint"
    );
  });

  for (const source of ["board", "column"]) {
    test(`promoting a floater passes the ${source} category to the composer`, async function (assert) {
      const card = this.fabricators.card({
        board_id: this.board.id,
        column_id: this.column.id,
      });
      this.column.cards = [card];

      if (source === "column") {
        this.board.category_ids = [];
        this.column.move_to_category_id = CATEGORY_ID;
      }

      const openNewTopic = sinon.stub().resolves();
      this.owner.register(
        "service:composer",
        class extends Service {
          openNewTopic = openNewTopic;
        }
      );
      await render(
        <template><BoardsBoardViewer @model={{this.model}} /></template>
      );
      await click(".discourse-boards-card__actions-trigger");
      await click(".fk-d-menu button:has(.d-icon-plus)");

      assert.true(openNewTopic.calledOnce, "the composer opens");
      assert.strictEqual(
        openNewTopic.firstCall.args[0].category?.id,
        CATEGORY_ID,
        "the composer receives the intended category"
      );
    });
  }
});
