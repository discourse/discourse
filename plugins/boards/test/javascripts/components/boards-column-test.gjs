import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BoardsColumn from "discourse/plugins/boards/discourse/components/boards-column";
import BoardsFabricators from "discourse/plugins/boards/discourse/lib/fabricators";

function cardSelector(cardId) {
  return `.discourse-boards-card[data-card-id="${cardId}"]`;
}

function daysAgoISO(days) {
  return new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
}

module("Integration | Component | BoardsColumn", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.fabricators = new BoardsFabricators(getOwner(this));
    this.board = this.fabricators.board({ id: 1, can_write: false });

    this.oldCard = this.fabricators.card({
      id: 101,
      title: "Old card",
      column_id: 10,
    });
    this.oldCard.recency_at = daysAgoISO(8);

    this.recentCard = this.fabricators.card({
      id: 102,
      title: "Recent card",
      column_id: 10,
    });
    this.recentCard.recency_at = daysAgoISO(1);

    this.column = this.fabricators.column({ id: 10, title: "Recent" });
    this.column.default_sort = "recency";
    this.column.cards = [this.oldCard, this.recentCard];

    this.renderColumn = async () => {
      await render(
        <template>
          <BoardsColumn
            @column={{this.column}}
            @board={{this.board}}
            @canWrite={{false}}
            @canManage={{false}}
            @linkedCardId={{this.linkedCardId}}
            @linkHighlightCardId={{this.linkHighlightCardId}}
          />
        </template>
      );
    };
  });

  test("hides cards outside the recency window", async function (assert) {
    await this.renderColumn();

    assert.dom(cardSelector(102)).exists("the recent card renders");
    assert.dom(cardSelector(101)).doesNotExist("the old card is filtered out");
    assert
      .dom(".discourse-boards-column__show-all")
      .exists("the hidden card is reachable behind the show-all button");
  });

  test("keeps the deep-linked card rendered once its highlight has faded", async function (assert) {
    // The pulse highlight clears itself when its animation ends; the card it
    // pointed at has to stay on the board after that.
    this.linkedCardId = 101;
    this.linkHighlightCardId = null;

    await this.renderColumn();

    assert
      .dom(cardSelector(101))
      .exists("the deep-linked card still bypasses the recency window")
      .doesNotHaveClass(
        "discourse-boards-card--link-highlighted",
        "the faded pulse highlight is not reapplied"
      );
  });

  test("pulses the deep-linked card while its highlight is active", async function (assert) {
    this.linkedCardId = 101;
    this.linkHighlightCardId = 101;

    await this.renderColumn();

    assert
      .dom(cardSelector(101))
      .hasClass(
        "discourse-boards-card--link-highlighted",
        "the linked card is highlighted"
      );
    assert
      .dom(cardSelector(102))
      .doesNotHaveClass(
        "discourse-boards-card--link-highlighted",
        "other cards are left alone"
      );
  });
});
