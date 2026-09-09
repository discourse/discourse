import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { shouldRefetchMovedCardPayload } from "discourse/plugins/boards/discourse/components/boards-board-viewer";
import { shouldInsertSourceDropIndicator } from "discourse/plugins/boards/discourse/components/boards-card";
import {
  recencyDropIndicatorInsertBefore,
  shouldAnimateDropIndicatorPlacement,
} from "discourse/plugins/boards/discourse/components/boards-column";
import { autoScrollSpeedForPointer } from "discourse/plugins/boards/discourse/lib/boards-auto-scroll";

function createDropTarget() {
  const column = document.createElement("div");
  column.className = "discourse-boards-column";

  const cardsContainer = document.createElement("div");
  cardsContainer.className = "discourse-boards-column__cards";

  column.append(cardsContainer);
  return column;
}

module("Boards | Unit | Components | boards drop", function (hooks) {
  setupTest(hooks);

  test("the initial placeholder in the source column does not animate", function (assert) {
    assert.false(
      shouldAnimateDropIndicatorPlacement({
        hadIndicator: false,
        columnId: 10,
        fromColumnId: 10,
        hasPlacedIndicator: false,
      }),
      "it skips the first placeholder animation in the source column"
    );
    assert.true(
      shouldAnimateDropIndicatorPlacement({
        hadIndicator: true,
        columnId: 10,
        fromColumnId: 10,
        hasPlacedIndicator: true,
      }),
      "it still animates after the placeholder already exists"
    );
    assert.true(
      shouldAnimateDropIndicatorPlacement({
        hadIndicator: false,
        columnId: 20,
        fromColumnId: 10,
        hasPlacedIndicator: false,
      }),
      "it still animates the initial placement in a different column"
    );
    assert.true(
      shouldAnimateDropIndicatorPlacement({
        hadIndicator: false,
        columnId: 10,
        fromColumnId: 10,
        hasPlacedIndicator: true,
      }),
      "it animates when re-entering the source column later in the drag"
    );
  });

  test("source placeholder insertion is skipped once a live placeholder exists", function (assert) {
    const root = document.createElement("div");

    assert.true(
      shouldInsertSourceDropIndicator(root),
      "it allows the source placeholder before any live placeholder exists"
    );

    const sourceIndicator = document.createElement("div");
    sourceIndicator.className =
      "discourse-boards-column__drop-indicator discourse-boards-column__drop-indicator--source";
    root.append(sourceIndicator);

    assert.true(
      shouldInsertSourceDropIndicator(root),
      "it ignores the hidden source placeholder"
    );

    const liveIndicator = document.createElement("div");
    liveIndicator.className = "discourse-boards-column__drop-indicator";
    root.append(liveIndicator);

    assert.false(
      shouldInsertSourceDropIndicator(root),
      "it skips inserting the source placeholder after dragover has created a live placeholder"
    );
  });

  test("recency drop indicator target falls before the show older button when all cards are hidden", function (assert) {
    const target = createDropTarget();
    const cardsContainer = target.querySelector(
      ".discourse-boards-column__cards"
    );
    const showAllButton = document.createElement("button");
    showAllButton.className = "discourse-boards-column__show-all";
    cardsContainer.append(showAllButton);

    assert.strictEqual(
      recencyDropIndicatorInsertBefore(cardsContainer, [], 101),
      showAllButton,
      "the show older button is used as the insertion point"
    );
  });

  test("column drag auto-scroll speed follows pointer edge proximity", function (assert) {
    const verticalRect = { top: 100, bottom: 500 };
    const horizontalRect = { left: 100, right: 500 };

    assert.strictEqual(
      autoScrollSpeedForPointer(300, verticalRect),
      0,
      "it does not scroll away from the column edges"
    );
    assert.true(
      autoScrollSpeedForPointer(110, verticalRect) < 0,
      "it scrolls up near the top edge"
    );
    assert.true(
      autoScrollSpeedForPointer(490, verticalRect) > 0,
      "it scrolls down near the bottom edge"
    );
    assert.true(
      Math.abs(autoScrollSpeedForPointer(100, verticalRect)) >
        Math.abs(autoScrollSpeedForPointer(150, verticalRect)),
      "it scrolls faster closer to the edge"
    );
    assert.true(
      autoScrollSpeedForPointer(490, horizontalRect, "x") > 0,
      "it supports horizontal scrolling near the right edge"
    );
  });

  test("moved topic cards without existing topic data require a board refetch", function (assert) {
    assert.true(
      shouldRefetchMovedCardPayload(null, {
        id: 101,
        column_id: 20,
        topic_id: 9001,
      }),
      "it refetches when a new topic card payload omits the topic"
    );
    assert.false(
      shouldRefetchMovedCardPayload(
        { id: 101, topic_id: 9001, topic: { id: 9001 } },
        { id: 101, column_id: 20, topic_id: 9001 }
      ),
      "it merges stripped payloads for cards already visible to the client"
    );
    assert.false(
      shouldRefetchMovedCardPayload(null, { id: 102, column_id: 20 }),
      "it does not refetch floating cards"
    );
  });
});
