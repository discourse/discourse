import {
  click,
  currentURL,
  find,
  triggerEvent,
  visit,
} from "@ember/test-helpers";
import { test } from "qunit";
import topicFixtures from "discourse/tests/fixtures/topic";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Boards add topic footer button", function (needs) {
  needs.user({ can_edit_any_boards: true });

  test("uses the bookmark highlight while the topic is on a board", async function (assert) {
    const topic = {
      ...topicFixtures["/t/280/1.json"],
      bookmarks: [{ id: 3, bookmarkable_id: 280, bookmarkable_type: "Topic" }],
      board_memberships: [
        {
          board_id: 1,
          board_name: "Roadmap",
          board_slug: "roadmap",
          cards: [{ card_id: 10, column_id: 11, column_title: "Next" }],
        },
      ],
    };
    pretender.get("/t/280.json", () => response(topic));
    pretender.get("/t/280", () =>
      response({ ...topic, board_memberships: [] })
    );

    await visit("/t/internationalization-localization/280");

    const icon = ".boards-add-from-topic-button .d-icon-table-columns";
    const bookmarkColor = getComputedStyle(
      find(".topic-footer-button.bookmarked .d-icon-bookmark")
    ).color;
    assert
      .dom(icon)
      .hasStyle({ color: bookmarkColor }, "highlights an existing membership");

    await publishToMessageBus("/topic/280", { reload_topic: true });

    assert.notStrictEqual(
      getComputedStyle(find(icon)).color,
      bookmarkColor,
      "clears the highlight when the last membership is removed"
    );
  });

  test("opens the selected board from the topic footer submenu", async function (assert) {
    const board = {
      id: 1,
      name: "Roadmap",
      slug: "roadmap",
      columns: [
        { id: 11, title: "Next", cards: [] },
        { id: 12, title: "Done", cards: [] },
      ],
    };
    pretender.get("/boards/api/boards/available", () =>
      response({ boards: [board] })
    );
    pretender.get("/boards/api/boards/1.json", () =>
      response({ board, columns: board.columns })
    );

    await visit("/t/internationalization-localization/280");

    assert
      .dom(
        ".topic-footer-main-buttons__actions #topic-footer-button-boards-add-from-topic"
      )
      .exists();
    assert
      .dom("#topic-footer-button-boards-add-from-topic .d-icon-table-columns")
      .exists("displays the table-columns icon");

    await click("#topic-footer-button-boards-add-from-topic");

    assert.dom(".discourse-boards-add-from-topic-menu").exists();

    const boardButton = ".discourse-boards-add-from-topic-menu__board";
    await triggerEvent(boardButton, "pointerenter", { pointerType: "touch" });
    assert.dom(".discourse-boards-add-from-topic-column-menu").doesNotExist();
    await triggerEvent(boardButton, "pointerenter", { pointerType: "mouse" });

    assert
      .dom(".discourse-boards-add-from-topic-column-menu__column")
      .exists({ count: 2 });

    const columnMenu = ".discourse-boards-add-from-topic-column-menu";
    assert
      .dom(".discourse-boards-add-from-topic-column-menu__title")
      .doesNotExist();
    await click(boardButton);
    assert
      .dom(columnMenu)
      .exists("clicking a hovered board keeps its columns open");
    await click(boardButton);
    assert
      .dom(columnMenu)
      .doesNotExist("clicking again toggles the columns closed");
    await click(boardButton);
    assert.dom(columnMenu).exists("clicking again reopens the columns");
    const viewBoard = `${columnMenu} a`;
    assert
      .dom(`${columnMenu} .dropdown-menu__divider`)
      .exists("separates navigation from column actions");
    assert
      .dom(viewBoard)
      .hasText("View board", "labels the navigation link")
      .hasAttribute("href", "/boards/roadmap/1", "links to the selected board");
    await click(viewBoard);

    assert.strictEqual(currentURL(), "/boards/roadmap/1", "opens the board");
    assert.dom(columnMenu).doesNotExist("closes the column submenu");
    assert
      .dom(".discourse-boards-add-from-topic-menu")
      .doesNotExist("closes the board menu");
  });
});
