import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import PreloadStore from "discourse/lib/preload-store";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

const BOARDS_LINK =
  '.sidebar-section[data-section-name="community"] .sidebar-section-link[data-link-name="boards"]';
const BOARDS_TAB = '.mobile-tab-bar__tab[data-key="boards"]';

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

acceptance("Boards mobile footer - anonymous", function (needs) {
  needs.mobileView();
  needs.settings({ boards_enabled: true, mobile_footer_navigation: true });
  needs.hooks.beforeEach(() => {
    PreloadStore.store("boards:visibility", { can_see_any_boards: true });
  });
  needs.pretender((server, helper) => {
    const board = { id: 1, name: "Roadmap", slug: "roadmap" };
    server.get("/boards/api/boards.json", () =>
      helper.response({ boards: [board] })
    );
    server.get("/boards/api/boards/1.json", () => helper.response({ board }));
  });

  test("the Boards tab opens the list and stays active inside a board", async function (assert) {
    await visit("/latest");

    assert
      .dom(BOARDS_TAB)
      .hasText(i18n("boards.manage.title"), "names the tab");
    assert.dom(`${BOARDS_TAB} .d-icon-boards`).exists("uses the Boards icon");
    await click(BOARDS_TAB);

    assert.strictEqual(currentURL(), "/boards", "opens the boards index");
    assert
      .dom(BOARDS_TAB)
      .hasAttribute("aria-current", "page", "selects Boards");
    await click(".discourse-boards-board-card__name");

    assert.strictEqual(currentURL(), "/boards/roadmap/1", "opens the board");
    assert
      .dom(BOARDS_TAB)
      .hasAttribute("aria-current", "page", "keeps Boards selected");
  });

  test("tapping Boards from a board opened directly returns to the list", async function (assert) {
    await visit("/boards/roadmap/1");
    await click(BOARDS_TAB);

    assert.strictEqual(currentURL(), "/boards", "returns to the boards index");
  });
});

acceptance(
  "Boards mobile footer - user without visible boards",
  function (needs) {
    needs.mobileView();
    needs.user({ can_see_any_boards: false });
    needs.settings({ boards_enabled: true, mobile_footer_navigation: true });

    test("omits Boards from the footer", async function (assert) {
      await visit("/latest");

      assert.dom(".mobile-tab-bar").exists("shows the mobile footer");
      assert.dom(BOARDS_TAB).doesNotExist("hides the Boards tab");
    });
  }
);
