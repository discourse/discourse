import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  findAll,
  settled,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { test } from "qunit";
import AboutFixtures from "discourse/tests/fixtures/about";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Page shell | narrow screen menus", function (needs) {
  needs.user();
  needs.mobileView();
  needs.settings({
    enable_page_shell_prototype: true,
    enable_main_outlet_grid_layout_change: true,
    navigation_menu: "sidebar",
  });

  test("Escape closes navigation and restores the opener", async function (assert) {
    await visit("/");
    await click("#toggle-hamburger-menu");
    assert.dom(".sidebar-hamburger-dropdown").exists();

    await triggerKeyEvent(".sidebar-hamburger-dropdown a", "keydown", "Escape");

    assert.dom(".sidebar-hamburger-dropdown").doesNotExist();
    assert.dom("#toggle-hamburger-menu").isFocused();
  });

  test("Escape closes the user menu and restores the opener", async function (assert) {
    await visit("/");
    await click("#toggle-current-user");
    assert.dom(".user-menu").exists();

    await triggerKeyEvent(".user-menu", "keydown", "Escape");

    assert.dom(".user-menu").doesNotExist();
    assert.dom("#toggle-current-user").isFocused();
  });

  test("a nested control can claim Escape", async function (assert) {
    await visit("/");
    await click("#toggle-hamburger-menu");
    const link = document.querySelector(".sidebar-hamburger-dropdown a");
    link.addEventListener("keydown", (event) => event.preventDefault(), {
      once: true,
    });

    await triggerKeyEvent(link, "keydown", "Escape");

    assert.dom(".sidebar-hamburger-dropdown").exists();
  });
});

acceptance("Page shell | regions", function (needs) {
  needs.user();
  needs.settings({
    enable_page_shell_prototype: true,
    enable_main_outlet_grid_layout_change: true,
    navigation_menu: "sidebar",
  });

  needs.pretender((server, helper) => {
    server.get("/about.json", () => {
      const fixture = AboutFixtures["about.json"];
      return helper.response({
        ...fixture,
        about: {
          ...fixture.about,
          contact_email: "contact@example.com",
          stats: { ...fixture.about.stats, likes_count: 0 },
        },
      });
    });
    server.get("/c/1/leaderboard.json", () =>
      helper.response({
        users: [{ id: 32, username: "most-liked", likes_received: 12 }],
      })
    );
  });

  test("Category guide shows category information and both blocks", async function (assert) {
    await visit("/c/bug/1");
    assert
      .dom(".page-shell-context-picker-trigger .d-button-label")
      .hasText(
        "Follow page (Category guide)",
        "follows the category listing automatically"
      );

    const guide = "#page-shell-context .context-category";
    await waitFor(`${guide} .context-category__contributors li`);
    await waitFor(`${guide} .context-category__topics li`);
    assert.dom(`${guide} h2`).hasText("bug", "shows the current category");
    assert
      .dom(`${guide} .context-category__description`)
      .exists("shows the description");
    assert
      .dom(`${guide} .context-category__topics a`)
      .exists("lists links to hot topics");
    assert
      .dom(`${guide} .context-category__contributor-name`)
      .hasText("most-liked", "links to the contributor");
    assert
      .dom(`${guide} .context-category__likes`)
      .hasText("12 likes", "shows likes received");

    await visit("/latest");
    await click(".page-shell-context-picker-trigger");
    assert
      .dom('[data-context-view-option="category-guide"]')
      .doesNotExist("omits the category guide without a category");
  });

  test("About shows links to top-level categories", async function (assert) {
    await visit("/latest");

    const panel = "#page-shell-context .context-category-navigation";
    assert
      .dom(".page-shell-context-picker-trigger .d-button-label")
      .hasText("Follow page (About)", "shows About as the automatic fallback");
    assert
      .dom(".page-shell-context-picker-trigger .d-icon-bullseye")
      .exists("shows the bullseye when Follow page displays About");
    assert.dom(`${panel} h2`).hasText("All topics", "labels the navigation");
    assert
      .dom(`${panel} a[href="/c/bug/1"]`)
      .includesText("bug", "links to the category");
    assert
      .dom(`${panel} a[href="/categories"]`)
      .doesNotExist("omits the categories index link");
    assert
      .dom(`${panel} a[href*="/uncategorized/"]`)
      .doesNotExist("omits uncategorized");

    const about = "#page-shell-context .context-about";
    const { description } = AboutFixtures["about.json"].about;
    await waitFor(`${about} .context-about__description`);
    assert
      .dom(`${panel} + .context-about`)
      .exists("shows About below navigation");
    assert
      .dom(`${about} .context-about__description`)
      .hasText(description, "shows the site description");

    assert
      .dom(`${about} .about__activities .topics`)
      .includesText(
        "169 topics",
        "shows the same weekly topic count as the About page"
      );
    assert
      .dom(`${about} .about__activities .likes`)
      .includesText("0 likes", "shows zero likes from the server");
    assert
      .dom(`${about} .powered-by-discourse`)
      .includesText(
        "Powered by Discourse",
        "shows the attribution below the About content"
      );
    assert
      .dom(`${about} a[href="mailto:contact@example.com"]`)
      .exists("links to the published contact");

    await click(`${panel} a[href="/c/bug/1"]`);
    await waitFor("#page-shell-context .context-category");
    assert
      .dom("#page-shell-context .context-category h2")
      .hasText("bug", "switches to the guide when the category opens in Main");

    assert
      .dom(`${panel} a[href="/latest"]`)
      .hasText("Browse all topics", "links to Latest from the category guide");
    await click(`${panel} a[href="/latest"]`);
    assert
      .dom(`${panel} a[href="/latest"]`)
      .doesNotExist("omits the Latest link from About");
    assert
      .dom(`${panel} h2`)
      .hasText("All topics", "returns to the top-level list");
    assert
      .dom("#page-shell-context .context-category")
      .doesNotExist("leaves the individual category guide");
  });

  test("the shell owns its page regions and composer directly", async function (assert) {
    await visit("/");

    const shell = "#main-outlet-wrapper.page-shell";
    assert.dom("#main-outlet-wrapper").exists({ count: 1 });
    assert.dom(`${shell} > .page-shell__header`).exists();
    assert.dom(`${shell} > .sidebar-wrapper.page-shell__navigation`).exists();
    assert.dom(`${shell} > main#main-outlet.page-shell__main`).exists();
    assert.dom(`${shell} > footer.page-shell__footer`).exists();
    assert.dom(`${shell} > aside.page-shell__context`).exists();
    assert.dom(`${shell} > #reply-control`).exists();
    assert.dom(`${shell} > .powered-by-discourse`).doesNotExist();
    assert.dom("main, [role=main]").exists({ count: 1 });
  });

  test("the header button opens and closes Context", async function (assert) {
    await visit("/");

    const toggle = "#toggle-context-panel";
    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "true", "Context starts open");
    assert
      .dom(".page-shell-context-picker-trigger")
      .hasAttribute(
        "data-context-view",
        "follow-page",
        "The Context selector is visible above the panel"
      );

    await click(toggle);

    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "false", "The button reports closed");
    assert.dom("#page-shell-context").doesNotExist("The panel closes");
    assert
      .dom(".page-shell-context-picker-trigger")
      .doesNotExist("The Context selector closes with the panel");

    await click(toggle);

    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "true", "The button reports open");
    assert.dom("#page-shell-context").exists("The panel reopens");
  });

  test("moving Context after Main moves its header toggle", async function (assert) {
    await visit("/");
    await click(".page-shell-controls summary");
    await fillIn('.page-shell-controls select[name="contextPosition"]', "end");

    const toggle = ".page-shell__context-toggle.--edge #toggle-context-panel";
    assert
      .dom("#toggle-context-panel")
      .exists({ count: 1 }, "One toggle renders");
    assert
      .dom(toggle)
      .hasAttribute(
        "aria-controls",
        "page-shell-context",
        "The edge toggle controls Context"
      );

    await click(toggle);
    assert.dom(toggle).hasAttribute("aria-expanded", "false", "Context closes");

    await click(toggle);
    assert.dom(toggle).hasAttribute("aria-expanded", "true", "Context reopens");
  });

  test("the Navigation toggle collapses to actionable sidebar icons", async function (assert) {
    await visit("/");

    const toggle = ".btn-sidebar-toggle";
    const links = ".page-shell__navigation .sidebar-section-link";
    const expandedCount = findAll(links).length;
    assert.true(expandedCount > 0, "Navigation starts with links");

    await click(toggle);

    assert
      .dom(".page-shell")
      .hasAttribute(
        "data-navigation",
        "rail",
        "Navigation collapses to a rail"
      );
    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "false", "The toggle reports collapsed");
    assert.true(
      findAll(links).length >= expandedCount,
      "The rail keeps the links"
    );
    assert
      .dom(`${links} .sidebar-section-link-prefix`)
      .exists("Links show icons");

    await click(toggle);

    assert
      .dom(".page-shell")
      .hasAttribute(
        "data-navigation",
        "open",
        "The toggle restores Navigation"
      );
  });

  test("keeps the full logo when the topic title appears in the shell header", async function (assert) {
    await visit("/t/internationalization-localization/280");

    getOwner(this).lookup("service:header").mainTopicTitleVisible = false;
    await settled();

    assert
      .dom(".page-shell__header-main .header-title")
      .exists("shows the topic title in the header");
    assert
      .dom(".page-shell__header-start .title")
      .doesNotHaveClass("title--minimized", "keeps the full logo");
  });

  test("the Topic view follows the current discussion", async function (assert) {
    const picker = ".page-shell-context-picker-trigger";
    const panel = "#page-shell-context .context-topic";

    await visit("/t/internationalization-localization/280");
    const option = '[data-context-view-option="topic"]';
    await click(picker);
    await waitFor(option);
    assert.dom(option).hasText("Topic summary", "labels the view");

    assert
      .dom(`${picker} .d-button-label`)
      .hasText(
        "Follow page (Topic summary)",
        "follows the open topic automatically"
      );
    assert.dom(`${option} .d-icon-file-lines`).exists("shows the topic icon");
    assert
      .dom('[data-context-view-option="follow-page"] .d-icon-bullseye')
      .exists("shows the bullseye for Follow page on topics");
    assert
      .dom('[data-context-view-option="about"] .d-icon-circle-info')
      .exists("shows the info icon for the separate About option");
    await click(option);

    assert
      .dom(panel)
      .hasAttribute("data-topic-id", "280", "shows the open topic");
    assert.dom(".context-topic__stats").exists("shows topic statistics");
    assert.dom(`${panel} h2`).doesNotExist("omits the repeated topic title");

    await visit("/t/130");

    assert
      .dom(picker)
      .hasAttribute(
        "data-context-view",
        "topic",
        "keeps Topic summary selected"
      );
    assert.dom(panel).hasAttribute("data-topic-id", "130", "updates the topic");

    await visit("/latest");

    await click(picker);
    assert.dom(option).doesNotExist("removes Topic off a discussion");
    assert
      .dom(picker)
      .hasAttribute("data-context-view", "follow-page", "falls back to About");
  });

  test("Context remembers a page-aware selection across automatic fallbacks", async function (assert) {
    const picker = ".page-shell-context-picker-trigger";

    await visit("/c/bug/1");
    await click(picker);
    await click('[data-context-view-option="category-guide"]');
    await visit("/latest");
    assert
      .dom(picker)
      .hasAttribute(
        "data-context-view",
        "follow-page",
        "uses About outside a category"
      );

    await visit("/t/internationalization-localization/280");
    assert
      .dom(picker)
      .hasAttribute(
        "data-context-view",
        "category-guide",
        "resumes the explicit view"
      );

    await click(picker);
    await click('[data-context-view-option="about"]');
    assert
      .dom("#page-shell-context .context-about")
      .exists("opens About on a topic");
    await click(picker);
    await click('[data-context-view-option="follow-page"]');
    assert
      .dom(`${picker} .d-button-label`)
      .hasText(
        "Follow page (Topic summary)",
        "clears the preference and follows Main"
      );

    await click(picker);
    await click('[data-context-view-option="about"]');
    await visit("/latest");
    assert
      .dom(`${picker} .d-button-label`)
      .hasText("About", "keeps the explicit About selection on Latest");
    await visit("/c/bug/1");
    assert
      .dom(`${picker} .d-button-label`)
      .hasText("About", "keeps About selected in the category");
    assert
      .dom("#page-shell-context .context-about")
      .exists("continues to show About");

    await click(picker);
    await click('[data-context-view-option="follow-page"]');
    assert
      .dom(`${picker} .d-button-label`)
      .hasText(
        "Follow page (Category guide)",
        "follows the category after clearing About"
      );
    await visit("/latest");
    assert
      .dom(`${picker} .d-button-label`)
      .hasText("Follow page (About)", "uses About as the automatic fallback");

    await click("#toggle-context-panel");
    await visit("/latest");
    assert
      .dom("#page-shell-context")
      .doesNotExist("navigation leaves Context closed");
  });

  test("Preferences has no header Context button", async function (assert) {
    await visit("/u/eviltrout/preferences/tracking");

    assert
      .dom("#toggle-context-panel")
      .doesNotExist("Preferences offers no Context panel to open");
  });
});
