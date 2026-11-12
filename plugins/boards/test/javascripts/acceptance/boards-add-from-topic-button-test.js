import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Boards add topic footer button", function (needs) {
  needs.user({ can_edit_any_boards: true });

  test("renders with the core topic footer buttons and opens its menu", async function (assert) {
    pretender.get("/boards/api/boards/available", () =>
      response({
        boards: [
          {
            id: 1,
            name: "Roadmap",
            columns: [
              { id: 11, title: "Next", cards: [] },
              { id: 12, title: "Done", cards: [] },
            ],
          },
        ],
      })
    );

    await visit("/t/internationalization-localization/280");

    assert
      .dom(
        ".topic-footer-main-buttons__actions #topic-footer-button-boards-add-from-topic"
      )
      .exists();
    assert
      .dom("#topic-footer-button-boards-add-from-topic .d-icon-boards")
      .exists();

    await click("#topic-footer-button-boards-add-from-topic");

    assert.dom(".discourse-boards-add-from-topic-menu").exists();

    await triggerEvent(
      ".discourse-boards-add-from-topic-menu__board-item",
      "mouseenter"
    );

    assert
      .dom(".discourse-boards-add-from-topic-column-menu__column")
      .exists({ count: 2 });
  });
});
