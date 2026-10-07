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

const HTTP_NOT_FOUND = 404;
const CONFIRM_BUTTON =
  ".discourse-boards-constraint-fix-modal .d-modal__footer .btn-primary";
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

      const onConfirm = sinon.spy();
      this.constraintModel = {
        onConfirm,
        topic: { category_id: 1 },
        mismatches: {
          needsCategory: true,
          boardCategoryIds: [CATEGORY_ID],
        },
      };
      await render(
        <template>
          <BoardsConstraintFix
            @closeModal={{this.closeModal}}
            @model={{this.constraintModel}}
          />
        </template>
      );

      assert.dom(`[data-category-id="${CATEGORY_ID}"]`).hasText(CATEGORY_NAME);
      assert
        .dom(CONFIRM_BUTTON)
        .isEnabled("the loaded category can be confirmed");

      await click(CONFIRM_BUTTON);

      assert.deepEqual(
        onConfirm.args,
        [[{ category_id: CATEGORY_ID }]],
        "confirmation uses the loaded category"
      );
    });
  }

  test("a missing category cannot be confirmed in the constraint dialog", async function (assert) {
    pretender.get("/categories/find", () =>
      response(HTTP_NOT_FOUND, { errors: ["Not found"] })
    );
    this.constraintModel = {
      topic: { category_id: 1 },
      mismatches: {
        needsCategory: true,
        boardCategoryIds: [CATEGORY_ID],
      },
    };

    await render(
      <template>
        <BoardsConstraintFix
          @closeModal={{this.closeModal}}
          @model={{this.constraintModel}}
        />
      </template>
    );

    assert
      .dom("[data-category-id]")
      .doesNotExist("the missing category is not offered");
    assert
      .dom(CONFIRM_BUTTON)
      .isDisabled("confirmation requires an available category");
  });

  test("a partial category response keeps the settings selector available", async function (assert) {
    this.board.category_ids = [CATEGORY_ID, ADDITIONAL_CATEGORY_ID];
    pretender.get("/categories/find", () =>
      response({ categories: [category] })
    );

    this.settingsModel.board = (await Board.createPayload(this.model)).board;

    await render(
      <template>
        <BoardsBoardSettings
          @closeModal={{this.closeModal}}
          @inline={{true}}
          @model={{this.settingsModel}}
        />
      </template>
    );

    assert
      .dom(".category-selector")
      .exists("the category selector remains available")
      .includesText(CATEGORY_NAME, "the accessible category remains selected");
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
    test.each(
      `promoting a floater with a ${source} category`,
      {
        available: { categoryIds: [CATEGORY_ID], alerts: 0 },
        missing: { categoryIds: [], alerts: 1 },
      },
      async function (assert, expected) {
        const alert = sinon.stub(this.owner.lookup("service:dialog"), "alert");
        if (!expected.categoryIds.length) {
          pretender.get("/categories/find", () => response(HTTP_NOT_FOUND, {}));
        }

        this.column.cards = [
          this.fabricators.card({
            board_id: this.board.id,
            column_id: this.column.id,
          }),
        ];
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

        assert.deepEqual(
          openNewTopic.args.map(([options]) => options.category?.id),
          expected.categoryIds,
          "only an available category is passed to the composer"
        );
        assert.strictEqual(
          alert.callCount,
          expected.alerts,
          "missing categories are reported"
        );
      }
    );
  }
});
