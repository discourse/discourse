import { getOwner } from "@ember/owner";
import { click, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import PermanentlyDeleteConfirmModal from "discourse/components/modal/permanently-delete-confirm";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import BoardsBoardViewer from "discourse/plugins/boards/discourse/components/boards-board-viewer";
import BoardsFabricators from "discourse/plugins/boards/discourse/lib/fabricators";

function columnSelector(columnId) {
  return `.discourse-boards-column[data-column-id="${columnId}"]`;
}

function cardSelector(cardId) {
  return `.discourse-boards-card[data-card-id="${cardId}"]`;
}

function columnCardIds(columnId) {
  return [
    ...document.querySelectorAll(
      `${columnSelector(columnId)} .discourse-boards-card`
    ),
  ].map((card) => parseInt(card.dataset.cardId, 10));
}

function recentISO(daysAgo) {
  return new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000).toISOString();
}

function stubCardRect(cardId, { top = 0, height = 48 } = {}) {
  const card = document.querySelector(cardSelector(cardId));
  sinon.stub(card, "getBoundingClientRect").returns({
    top,
    bottom: top + height,
    left: 0,
    right: 200,
    width: 200,
    height,
  });
}

module("Integration | Component | BoardsBoardViewer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new BoardsFabricators(getOwner(this));

    this.messageBus = getOwner(this).lookup("service:message-bus");
    this.originalClientId = this.messageBus.clientId;
    this.messageBus.clientId = "test-client";
    sinon.stub(this.messageBus, "subscribe");
    sinon.stub(this.messageBus, "unsubscribe");

    this.renderBoard = async (columns, boardOverrides = {}) => {
      const board = this.fabricators.board({
        id: 1,
        can_write: true,
        can_manage: false,
      });
      board.require_confirmation = false;
      Object.assign(board, boardOverrides);

      this.model = { board, columns };
      await render(
        <template>
          <BoardsBoardViewer
            @model={{this.model}}
            @highlightCardId={{this.highlightCardId}}
            @openBoardSettings={{this.openBoardSettings}}
          />
        </template>
      );
    };

    this.makeColumn = ({ id, title, cards = [], defaultSort } = {}) => {
      const column = this.fabricators.column({ id, title });
      column.default_sort = defaultSort;
      column.cards = cards;
      return column;
    };

    this.makeCard = ({ id, columnId, title, position, recencyAt } = {}) => {
      const card = this.fabricators.card({
        id,
        title,
        column_id: columnId,
      });
      card.position = position;
      card.recency_at = recencyAt;
      return card;
    };

    this.dragDataTransfer = null;
    this.dragCard = async (cardId) => {
      this.dragDataTransfer = new DataTransfer();
      stubCardRect(cardId);

      await triggerEvent(cardSelector(cardId), "dragstart", {
        clientX: 10,
        clientY: 10,
        dataTransfer: this.dragDataTransfer,
      });
    };

    this.dropOnColumn = async (columnId, { clientY = 0 } = {}) => {
      await triggerEvent(columnSelector(columnId), "drop", {
        clientY,
        dataTransfer: this.dragDataTransfer,
      });
    };
  });

  test("does not open board settings without manage permission", async function (assert) {
    const modal = getOwner(this).lookup("service:modal");
    const show = sinon.stub(modal, "show");
    this.openBoardSettings = true;

    await this.renderBoard([], { can_manage: false });
    await settled();

    assert.false(show.called, "the settings modal remains closed");
  });

  test("links board constraints while keeping the info tooltip", async function (assert) {
    await this.renderBoard([], {
      category_ids: [5],
      tag_names: ["priority"],
    });

    assert
      .dom(
        ".discourse-boards-board-viewer__constraint a.badge-category__wrapper"
      )
      .hasAttribute("href", "/c/extensibility/5");
    assert
      .dom(
        '.discourse-boards-board-viewer__constraint a.discourse-tag[data-tag-name="priority"]'
      )
      .hasAttribute("href", "/tag/priority");
    assert
      .dom(".discourse-boards-board-viewer__constraint .fk-d-tooltip__trigger")
      .exists();
  });

  hooks.afterEach(function () {
    this.messageBus.clientId = this.originalClientId;
    sinon.restore();
  });

  test("completes a priority drop with the source column from drag start", async function (assert) {
    const sourceCard = this.makeCard({
      id: 101,
      columnId: 10,
      title: "Fix checkout",
      position: 0,
    });
    const targetCard = this.makeCard({
      id: 102,
      columnId: 20,
      title: "Ship receipts",
      position: 0,
    });

    await this.renderBoard([
      this.makeColumn({ id: 10, title: "Todo", cards: [sourceCard] }),
      this.makeColumn({ id: 20, title: "Done", cards: [targetCard] }),
    ]);

    let requestData;
    pretender.put("/boards/api/boards/1/cards/101", (request) => {
      requestData = parsePostData(request.requestBody);

      return response({
        card: {
          id: 101,
          column_id: 20,
          position: 1,
        },
      });
    });

    stubCardRect(102, { top: 0, height: 48 });
    await this.dragCard(101);
    await this.dropOnColumn(20, { clientY: 30 });

    assert.strictEqual(requestData.card.column_id, "20");
    assert.strictEqual(requestData.card.after_card_id, "102");
    assert.deepEqual(
      columnCardIds(10),
      [],
      "it removes the card from the source column"
    );
    assert.deepEqual(
      columnCardIds(20),
      [102, 101],
      "it inserts the card after the target card"
    );
    assert
      .dom(`${columnSelector(20)} ${cardSelector(101)}`)
      .hasClass(
        "discourse-boards-card--drop-highlighted",
        "it highlights the dropped card"
      );
  });

  test("dropping into a recency column sends no after_card_id and places the card first", async function (assert) {
    const sourceCard = this.makeCard({
      id: 101,
      columnId: 10,
      title: "Fix checkout",
      position: 0,
    });
    const targetCard = this.makeCard({
      id: 102,
      columnId: 20,
      title: "Ship receipts",
      recencyAt: recentISO(2),
    });

    await this.renderBoard([
      this.makeColumn({ id: 10, title: "Todo", cards: [sourceCard] }),
      this.makeColumn({
        id: 20,
        title: "Recent",
        cards: [targetCard],
        defaultSort: "recency",
      }),
    ]);

    let requestData;
    pretender.put("/boards/api/boards/1/cards/101", (request) => {
      requestData = parsePostData(request.requestBody);

      return response({
        card: {
          id: 101,
          column_id: 20,
          position: -1,
          recency_at: recentISO(1),
        },
      });
    });

    await this.dragCard(101);
    await this.dropOnColumn(20);

    assert.strictEqual(requestData.card.column_id, "20");
    assert.strictEqual(requestData.card.after_card_id, "");
    assert.deepEqual(
      columnCardIds(10),
      [],
      "it removes the card from the source column"
    );
    assert.deepEqual(
      columnCardIds(20),
      [101, 102],
      "it sorts the moved card to the top of the recency column"
    );
  });

  test("checks topic card constraints on the server before moving it", async function (assert) {
    const sourceCard = this.makeCard({
      id: 101,
      columnId: 10,
      title: "Fix checkout",
      position: 0,
    });
    sourceCard.topic_id = 777;
    sourceCard.topic = { id: 777, title: "Fix checkout" };

    const modal = getOwner(this).lookup("service:modal");
    sinon.stub(modal, "show").callsFake((component, opts) => {
      assert.deepEqual(opts.model.mismatches, {
        needsTags: false,
        needsCategory: true,
        boardTagNames: [],
        boardCategoryIds: [3],
      });
      opts.model.onConfirm({ category_id: 3 });
    });

    await this.renderBoard([
      this.makeColumn({ id: 10, title: "Todo", cards: [sourceCard] }),
      this.makeColumn({ id: 20, title: "Done", cards: [] }),
    ]);

    pretender.put(
      "/boards/api/boards/1/check-constraint-mismatches",
      (request) => {
        const requestData = parsePostData(request.requestBody);
        assert.strictEqual(requestData.topic_id, "777");
        assert.strictEqual(requestData.target_column_id, "20");

        return response({
          categories_needed: [3],
          tags_needed: [],
          constraints_need_fixing: true,
        });
      }
    );

    let moveRequestData;
    pretender.put("/boards/api/boards/1/cards/101", (request) => {
      moveRequestData = parsePostData(request.requestBody);
      return response({ card: { id: 101, column_id: 20, position: 0 } });
    });

    await this.dragCard(101);
    await this.dropOnColumn(20);

    assert.strictEqual(moveRequestData.constraint_fix.category_id, "3");
  });

  test("renders and highlights an old linked card in a recency column", async function (assert) {
    const linkedCard = this.makeCard({
      id: 101,
      columnId: 10,
      title: "Old linked card",
      recencyAt: recentISO(8),
    });
    const recentCard = this.makeCard({
      id: 102,
      columnId: 10,
      title: "Recent card",
      recencyAt: recentISO(1),
    });
    this.highlightCardId = linkedCard.id;

    await this.renderBoard([
      this.makeColumn({
        id: 10,
        title: "Recent",
        cards: [recentCard, linkedCard],
        defaultSort: "recency",
      }),
    ]);
    await settled();

    assert
      .dom(cardSelector(linkedCard.id))
      .exists(
        "the linked card is rendered despite falling outside the recency window"
      )
      .hasClass(
        "discourse-boards-card--link-highlighted",
        "the linked card receives the deep-link highlight"
      );
  });

  test("canceling the constraint fix while adding a topic card stops creation", async function (assert) {
    let addTopicAsCardModel;
    let postRequests = 0;

    const modal = getOwner(this).lookup("service:modal");
    sinon.stub(modal, "show").callsFake((component, opts) => {
      if (opts?.model?.onAddTopicAsCard) {
        addTopicAsCardModel = opts.model;
      } else if (opts?.model?.mismatches) {
        opts.model.onCancel();
      }

      return Promise.resolve();
    });

    await this.renderBoard(
      [this.makeColumn({ id: 10, title: "Todo", cards: [] })],
      { category_ids: [1], tag_names: [] }
    );

    pretender.put(
      "/boards/api/boards/1/check-constraint-mismatches",
      (request) => {
        const requestData = parsePostData(request.requestBody);
        assert.strictEqual(requestData.topic_id, "777");
        assert.strictEqual(requestData.target_column_id, "10");

        return response({
          categories_needed: [1],
          tags_needed: [],
          constraints_need_fixing: true,
        });
      }
    );

    pretender.post("/boards/api/boards/1/cards", () => {
      postRequests++;
      return response({ card: { id: 101, column_id: 10 } });
    });

    await click(".discourse-boards-column__add-btn");
    await click(".fk-d-menu li:last-child button");
    await addTopicAsCardModel.onAddTopicAsCard({
      topicId: 777,
      title: "Wrong category",
    });

    assert.strictEqual(postRequests, 0, "it does not create the card");
  });

  test("clicking and dragging on the board scrolls columns horizontally", async function (assert) {
    await this.renderBoard([
      this.makeColumn({
        id: 10,
        title: "Todo",
        cards: [
          this.makeCard({
            id: 101,
            columnId: 10,
            title: "Fix checkout",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 20,
        title: "Done",
        cards: [
          this.makeCard({
            id: 102,
            columnId: 20,
            title: "Ship receipts",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 30,
        title: "In Progress",
        cards: [
          this.makeCard({
            id: 103,
            columnId: 30,
            title: "Implement login page",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 40,
        title: "Review",
        cards: [
          this.makeCard({
            id: 104,
            columnId: 40,
            title: "Write integration test coverage",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 50,
        title: "Deploy",
        cards: [
          this.makeCard({
            id: 105,
            columnId: 50,
            title: "Deploy to staging",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 60,
        title: "Done",
        cards: [
          this.makeCard({
            id: 106,
            columnId: 60,
            title: "Deploy to production",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 70,
        title: "Cancelled",
        cards: [
          this.makeCard({
            id: 107,
            columnId: 70,
            title: "Cancel order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 80,
        title: "Archived",
        cards: [
          this.makeCard({
            id: 108,
            columnId: 80,
            title: "Archive order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 90,
        title: "On Hold",
        cards: [
          this.makeCard({
            id: 109,
            columnId: 90,
            title: "On hold order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 100,
        title: "Backlog",
        cards: [
          this.makeCard({
            id: 110,
            columnId: 100,
            title: "Backlog order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 110,
        title: "In Progress",
        cards: [
          this.makeCard({
            id: 111,
            columnId: 110,
            title: "In progress order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 120,
        title: "Review",
        cards: [
          this.makeCard({
            id: 112,
            columnId: 120,
            title: "Review order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 130,
        title: "Deploy",
        cards: [
          this.makeCard({
            id: 113,
            columnId: 130,
            title: "Deploy order",
            position: 0,
          }),
        ],
      }),
      this.makeColumn({
        id: 140,
        title: "Done",
        cards: [
          this.makeCard({
            id: 114,
            columnId: 140,
            title: "Done order",
            position: 0,
          }),
        ],
      }),
    ]);

    const container = document.querySelector(
      ".discourse-boards-board-container"
    );

    await triggerEvent(container, "pointerdown", {
      pointerId: 1,
      pointerType: "mouse",
      button: 0,
      clientX: 400,
      clientY: 100,
    });
    await triggerEvent(container, "pointermove", {
      pointerId: 1,
      pointerType: "mouse",
      clientX: -600,
      clientY: 100,
    });

    await new Promise((resolve) => requestAnimationFrame(resolve));

    assert.strictEqual(
      container.scrollLeft,
      1000,
      "it scrolls the container by the drag distance"
    );

    await triggerEvent(container, "pointerup", {
      pointerId: 1,
      pointerType: "mouse",
      clientX: 200,
      clientY: 100,
    });
  });

  test("deleting a column with many cards shows the permanently-delete confirm modal", async function (assert) {
    const cards = Array.from({ length: 6 }, (_, index) =>
      this.makeCard({
        id: 200 + index,
        columnId: 10,
        title: `Card ${index + 1}`,
        position: index,
      })
    );

    const modal = getOwner(this).lookup("service:modal");
    let modalComponent;
    let modalOptions;
    sinon.stub(modal, "show").callsFake((component, options) => {
      modalComponent = component;
      modalOptions = options;
      return Promise.resolve();
    });

    let saveRequests = 0;
    pretender.delete("/boards/api/boards/1/columns/10", () => {
      saveRequests++;
      return response(204);
    });
    pretender.get("/boards/api/boards/1.json", () =>
      response({ board: {}, columns: [] })
    );

    await this.renderBoard(
      [this.makeColumn({ id: 10, title: "Done", cards })],
      { can_manage: true }
    );

    await click(`${columnSelector(10)} .discourse-boards-column__menu-trigger`);
    await click(".discourse-boards-column__menu-delete");

    assert.strictEqual(
      modalComponent,
      PermanentlyDeleteConfirmModal,
      "it opens the permanently-delete confirm modal"
    );
    assert.strictEqual(
      modalOptions.model.confirmPhrase,
      "Done",
      "it passes the column title as the confirm phrase"
    );
    assert.strictEqual(
      typeof modalOptions.model.didConfirm,
      "function",
      "it wires up a didConfirm callback"
    );

    modalOptions.model.didConfirm();
    await settled();

    assert.strictEqual(
      saveRequests,
      1,
      "confirming the modal triggers the columns save"
    );
  });

  test("same-column recency drops are ignored", async function (assert) {
    const firstCard = this.makeCard({
      id: 101,
      columnId: 20,
      title: "Fix checkout",
      recencyAt: recentISO(1),
    });
    const secondCard = this.makeCard({
      id: 102,
      columnId: 20,
      title: "Ship receipts",
      recencyAt: recentISO(2),
    });
    let putRequests = 0;

    await this.renderBoard([
      this.makeColumn({
        id: 20,
        title: "Recent",
        cards: [firstCard, secondCard],
        defaultSort: "recency",
      }),
    ]);

    pretender.put("/boards/api/boards/1/cards/101", () => {
      putRequests++;
      return response({ card: { id: 101, column_id: 20 } });
    });

    await this.dragCard(101);
    await this.dropOnColumn(20);

    assert.strictEqual(putRequests, 0, "it does not save ignored drops");
    assert.deepEqual(
      columnCardIds(20),
      [101, 102],
      "it leaves the recency column order unchanged"
    );
  });
});
