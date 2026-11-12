import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import PreloadStore from "discourse/lib/preload-store";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const BOARDS_LINK =
  '.sidebar-section[data-section-name="community"] .sidebar-section-link[data-link-name="boards"]';

acceptance("Boards sidebar - enabled", function (needs) {
  needs.user({ can_manage_boards: false, can_see_any_boards: true });
  needs.settings({ boards_enabled: true, navigation_menu: "sidebar" });
  needs.pretender((server, helper) => {
    server.get("/boards/api/boards.json", () =>
      helper.response({ boards: [] })
    );
  });

  test("links to boards for users without management permissions", async function (assert) {
    await visit("/");

    assert
      .dom(BOARDS_LINK)
      .hasText(i18n("boards.manage.title"), "displays the Boards label")
      .hasAttribute("href", "/boards", "links to the boards index");
    assert
      .dom(`${BOARDS_LINK} .d-icon-boards`)
      .exists("displays the Boards icon");

    await click(BOARDS_LINK);

    assert.strictEqual(currentURL(), "/boards", "opens the boards index");
  });
});

acceptance("Boards sidebar - anonymous", function (needs) {
  needs.settings({ boards_enabled: true, navigation_menu: "sidebar" });
  needs.hooks.beforeEach(() => {
    PreloadStore.store("boards:visibility", { can_see_any_boards: true });
  });

  test("shows the link to anonymous visitors", async function (assert) {
    await visit("/");

    assert
      .dom(BOARDS_LINK)
      .hasAttribute(
        "href",
        "/boards",
        "anonymous visitors can discover boards"
      );
  });
});

acceptance("Boards sidebar - user without visible boards", function (needs) {
  needs.user({ can_manage_boards: true, can_see_any_boards: false });
  needs.settings({ boards_enabled: true, navigation_menu: "sidebar" });
  needs.hooks.beforeEach(() => {
    PreloadStore.store("boards:visibility", { can_see_any_boards: true });
  });

  test("hides the link even when anonymous visitors can see boards", async function (assert) {
    await visit("/");

    assert.dom(BOARDS_LINK).doesNotExist("the Boards link is hidden");
  });
});

acceptance(
  "Boards sidebar - anonymous without visible boards",
  function (needs) {
    needs.settings({ boards_enabled: true, navigation_menu: "sidebar" });
    needs.hooks.beforeEach(() => {
      PreloadStore.store("boards:visibility", { can_see_any_boards: false });
    });

    test("hides the link when anonymous visitors cannot see boards", async function (assert) {
      await visit("/");

      assert.dom(BOARDS_LINK).doesNotExist("the Boards link is hidden");
    });
  }
);

acceptance("Boards sidebar - disabled", function (needs) {
  needs.user({ can_see_any_boards: true });
  needs.settings({ boards_enabled: false, navigation_menu: "sidebar" });

  test("hides the link when boards are disabled", async function (assert) {
    await visit("/");

    assert.dom(BOARDS_LINK).doesNotExist("the Boards link is hidden");
  });
});
