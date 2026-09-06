import { module, test } from "qunit";
import Board from "discourse/plugins/boards/discourse/models/board";
import Card from "discourse/plugins/boards/discourse/models/card";
import Column from "discourse/plugins/boards/discourse/models/column";

module("Unit | Models | Boards titles", function () {
  test("board fancyTitle prefers the Unicode name", function (assert) {
    const board = Board.create({
      name: "Launch :rocket:",
      unicode_name: "Launch 🚀",
    });

    assert.strictEqual(board.fancyTitle, "Launch 🚀");
    assert.strictEqual(Board.create({ name: "Launch" }).fancyTitle, "Launch");
  });

  test("floater card fancyTitle prefers the Unicode title", function (assert) {
    const card = Card.create({
      card_type: "floater",
      title: "Launch :rocket:",
      unicode_title: "Launch 🚀",
    });

    assert.strictEqual(card.fancyTitle, "Launch 🚀");
  });

  test("topic card fancyTitle comes from its topic", function (assert) {
    const card = Card.create({
      card_type: "topic",
      topic: {
        title: "Topic :rocket:",
        unicode_title: "Topic 🚀",
      },
    });

    assert.strictEqual(card.fancyTitle, "Topic 🚀");
  });

  test("column fancyTitle prefers the Unicode title", function (assert) {
    const column = Column.create({
      title: "Doing :rocket:",
      unicode_title: "Doing 🚀",
    });

    assert.strictEqual(column.fancyTitle, "Doing 🚀");
    assert.strictEqual(Column.create({ title: "Doing" }).fancyTitle, "Doing");
  });

  test("copying models preserves their titles", function (assert) {
    const column = Column.create({
      title: "To Do :rocket:",
      unicode_title: "To Do 🚀",
      cards: [],
    }).copy({ cards: [{ id: 1, title: "Ship it" }] });
    const card = column.cards[0].copy({ notes: "Ready" });

    assert.strictEqual(column.fancyTitle, "To Do 🚀");
    assert.strictEqual(card.fancyTitle, "Ship it");
  });
});
