import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTags from "discourse/lib/render-tags";
import { membershipsFor } from "discourse/plugins/boards/discourse/lib/boards-topic-pill";

function membership({
  boardId,
  boardName,
  unicodeBoardName,
  cardId,
  columnTitle,
}) {
  return {
    board_id: boardId,
    board_name: boardName,
    unicode_board_name: unicodeBoardName,
    board_slug: boardName.toLowerCase(),
    cards: [
      {
        card_id: cardId,
        column_id: 11,
        column_title: columnTitle,
        column_color: "0088cc",
        column_icon: "list",
      },
    ],
  };
}

function sales() {
  return membership({
    boardId: 1,
    boardName: "Sales",
    cardId: 101,
    columnTitle: "In progress",
  });
}

function support() {
  return membership({
    boardId: 2,
    boardName: "Support",
    cardId: 201,
    columnTitle: "Queued",
  });
}

function topic(boardsMemberships) {
  return EmberObject.create({ board_memberships: boardsMemberships });
}

function parse(html) {
  const el = document.createElement("div");
  el.innerHTML = html;
  return el;
}

module("Boards | Unit | Lib | discourse-boards-topic-pill", function (hooks) {
  setupTest(hooks);

  test("renders the pill as a tag inside core's tag list", function (assert) {
    const el = parse(renderTags(topic([sales()]), { mode: "list" }));
    const pill = el.querySelector("a.discourse-boards-topic-pill");

    assert.dom(pill).exists("renders a pill");
    assert.dom(pill.parentElement).hasTagName("li");
    assert.dom(pill.closest("ul")).hasClass("discourse-tags");
    assert
      .dom(pill)
      .hasClass("discourse-tag", "reuses core's tag styling")
      .hasAttribute("href", "/boards/sales/1?card=101")
      .hasAttribute(
        "title",
        "This topic is in the In progress column of the Sales board"
      )
      .hasText("Sales");
  });

  test("titles the pill with a column count when a topic has several cards on one board", function (assert) {
    const board = sales();
    board.cards.push({
      card_id: 102,
      column_id: 12,
      column_title: "Done",
      column_color: "00aa66",
      column_icon: "check",
    });

    const el = parse(renderTags(topic([board]), { mode: "list" }));

    assert
      .dom("a.discourse-boards-topic-pill", el)
      .hasAttribute("title", "This topic is in 2 columns of the Sales board");
  });

  test("uses the Unicode column title", function (assert) {
    const board = sales();
    board.cards[0].column_title = "In progress :rocket:";
    board.cards[0].unicode_column_title = "In progress 🚀";

    const el = parse(renderTags(topic([board]), { mode: "list" }));

    assert
      .dom("a.discourse-boards-topic-pill", el)
      .hasAttribute(
        "title",
        "This topic is in the In progress 🚀 column of the Sales board"
      );
  });

  test("uses the Unicode board name for the pill label and title", function (assert) {
    const board = membership({
      boardId: 1,
      boardName: "Sales :fire:",
      unicodeBoardName: "Sales 🔥",
      cardId: 101,
      columnTitle: "In progress",
    });

    const el = parse(renderTags(topic([board]), { mode: "list" }));

    assert
      .dom("a.discourse-boards-topic-pill", el)
      .hasText("Sales 🔥")
      .hasAttribute(
        "title",
        "This topic is in the In progress column of the Sales 🔥 board"
      );
  });

  test("renders a single menu trigger carrying its boards when a topic is on several", function (assert) {
    const memberships = [sales(), support()];
    const el = parse(renderTags(topic(memberships)));
    const trigger = el.querySelector("a.discourse-boards-topic-pill--multiple");

    assert.dom(trigger.parentElement).hasTagName("li");
    assert
      .dom(trigger)
      .hasClass("discourse-tag")
      .hasAttribute("role", "button")
      .hasAttribute("tabindex", "0")
      .hasAttribute("aria-expanded", "false")
      .doesNotHaveAttribute("href", "it opens a menu instead of navigating")
      .hasText("2 boards");
    assert.dom("a.discourse-boards-topic-pill", el).exists({ count: 1 });

    // the boards ride along in data attributes, for the menu to read back
    assert
      .dom(trigger)
      .hasAttribute("data-card-count", "2")
      .hasAttribute("data-card-0-board-slug", "sales")
      .hasAttribute("data-card-0-column-title", "In progress")
      .hasAttribute("data-card-1-board-slug", "support");
    assert.deepEqual(
      membershipsFor(trigger),
      memberships.map((board) => ({
        board_id: board.board_id,
        board_name: board.board_name,
        board_slug: board.board_slug,
        cards: board.cards.map((card) => ({
          card_id: card.card_id,
          column_title: card.column_title,
          column_color: card.column_color,
          column_icon: card.column_icon,
        })),
      }))
    );
  });

  test("carries every column of a board a topic has several cards on", function (assert) {
    const board = sales();
    board.cards.push({
      card_id: 102,
      column_id: 12,
      column_title: "Done",
      column_color: "00aa66",
      column_icon: "check",
    });
    const el = parse(renderTags(topic([board, support()])));
    const trigger = el.querySelector("a.discourse-boards-topic-pill--multiple");

    const [first] = membershipsFor(trigger);
    assert.deepEqual(
      first.cards.map((card) => card.column_title),
      ["In progress", "Done"]
    );
  });

  test("carries Unicode column titles for the multiple-board menu", function (assert) {
    const board = sales();
    board.cards[0].column_title = "In progress :rocket:";
    board.cards[0].unicode_column_title = "In progress 🚀";
    const el = parse(renderTags(topic([board, support()])));
    const trigger = el.querySelector("a.discourse-boards-topic-pill--multiple");

    assert
      .dom(trigger)
      .hasAttribute("data-card-0-column-title", "In progress 🚀");
    assert.strictEqual(
      membershipsFor(trigger)[0].cards[0].column_title,
      "In progress 🚀"
    );
  });

  test("leaves out data for a column with no colour or icon", function (assert) {
    const board = sales();
    board.cards[0].column_color = null;
    board.cards[0].column_icon = null;
    const el = parse(renderTags(topic([board, support()])));
    const trigger = el.querySelector("a.discourse-boards-topic-pill--multiple");

    const [{ cards }] = membershipsFor(trigger);
    assert.strictEqual(cards[0].column_color, undefined);
    assert.strictEqual(cards[0].column_icon, undefined);
    assert.strictEqual(cards[0].column_title, "In progress");
  });

  test("lists the boards instead of a menu when the caller wants inert markup", function (assert) {
    const el = parse(
      renderTags(topic([sales(), support()]), { tagName: "span" })
    );

    assert.dom(".discourse-boards-topic-pill--multiple", el).doesNotExist();
    assert.dom(".discourse-tags__tag-separator", el).exists({ count: 1 });
    assert.deepEqual(
      [...el.querySelectorAll("span.discourse-boards-topic-pill")].map((pill) =>
        pill.textContent.trim()
      ),
      ["Sales", "Support"]
    );
  });

  test("renders nothing when the topic is not on a board", function (assert) {
    assert.strictEqual(renderTags(topic([]), {}), "");
  });
});
