import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  findAll,
  select,
  settled,
  triggerKeyEvent,
  visit,
  waitFor,
} from "@ember/test-helpers";
import { test } from "qunit";
import AboutFixtures from "discourse/tests/fixtures/about";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
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

  let hasDescriptions;
  needs.hooks.beforeEach(() => {
    hasDescriptions = true;
  });

  needs.pretender((server, helper) => {
    server.get("/about.json", () => {
      const response = AboutFixtures["about.json"];
      return helper.response({
        ...response,
        about: {
          ...response.about,
          stats: { ...response.about.stats, users_count: 42 },
          site_creation_date: "2024-01-01",
          description: hasDescriptions ? response.about.description : "",
          extended_site_description: hasDescriptions
            ? "<p>A place for community discussion.</p>"
            : "",
        },
      });
    });
    server.get("/c/bug/1/none/l/hot.json", () =>
      helper.response(discoveryFixtures["/c/bug/1/l/latest.json"])
    );
    server.get("/c/1/leaderboard.json", () =>
      helper.response({
        users: [{ id: 32, username: "most-liked", likes_received: 12 }],
      })
    );
  });

  test("Category guide shows category information and both blocks", async function (assert) {
    await visit("/c/bug/1");
    await select(".page-shell__header-context select", "category-guide");

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
    assert
      .dom(".page-shell__header-context select option[value='category-guide']")
      .doesNotExist("omits the category guide without a category");
  });

  test("About is the default Context view and uses the About page content", async function (assert) {
    await visit("/");

    const { title, description } = AboutFixtures["about.json"].about;
    const panel = "#page-shell-context .context-about";
    await waitFor(`${panel} .about__extended-description p`);
    assert
      .dom(".page-shell__header-context select option:checked")
      .hasText("About", "selects About by default");
    assert.dom(`${panel} h2`).hasText(title, "shows the community title");
    assert
      .dom(`${panel} .short-description`)
      .hasText(description, "shows the description from the About page");
    assert
      .dom(`${panel} .about__extended-description p`)
      .hasText(
        "A place for community discussion.",
        "renders the extended description"
      );

    assert
      .dom(`${panel} .nav-pills`)
      .doesNotExist("omits the standalone About navigation");
    assert
      .dom(`${panel} a[href="/about"]`)
      .doesNotExist("omits the About page link");
  });

  test("About displays community information without custom descriptions", async function (assert) {
    hasDescriptions = false;
    await visit("/");

    const panel = "#page-shell-context .context-about";
    await waitFor(`${panel} .about__stats-item.members`);

    assert
      .dom(`${panel} .about__stats-item.members`)
      .includesText("42", "shows the member count");
    assert
      .dom(`${panel} .short-description`)
      .doesNotExist("has no custom description");
    assert.dom(`${panel} .about__admins`).exists("shows the community admins");
    assert.dom(`${panel} .about__activities`).exists("shows the site activity");
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
      .dom(".page-shell__header-context select")
      .hasValue("about", "The Context selector is visible above the panel");

    await click(toggle);

    assert
      .dom(toggle)
      .hasAttribute("aria-expanded", "false", "The button reports closed");
    assert.dom("#page-shell-context").doesNotExist("The panel closes");
    assert
      .dom(".page-shell__header-context select")
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
    const picker = ".page-shell__header-context select";
    const panel = "#page-shell-context .context-topic";

    await visit("/t/internationalization-localization/280");
    const option = `${picker} option[value="topic"]`;
    await waitFor(option);
    assert.dom(option).hasText("Topic summary", "labels the view");

    assert
      .dom(picker)
      .hasValue("about", "opening a topic keeps the existing view");
    await fillIn(picker, "topic");

    assert
      .dom(panel)
      .hasAttribute("data-topic-id", "280", "shows the open topic");
    assert.dom(".context-topic__stats").exists("shows topic statistics");
    assert.dom(`${panel} h2`).doesNotExist("omits the repeated topic title");

    await visit("/t/130");

    assert.dom(picker).hasValue("topic", "keeps Topic summary selected");
    assert.dom(panel).hasAttribute("data-topic-id", "130", "updates the topic");

    await visit("/latest");

    assert
      .dom(`${picker} option[value="topic"]`)
      .doesNotExist("removes Topic off a discussion");
    assert.dom(picker).hasValue("about", "falls back to About");
  });

  test("Preferences has no header Context button", async function (assert) {
    await visit("/u/eviltrout/preferences/tracking");

    assert
      .dom("#toggle-context-panel")
      .doesNotExist("Preferences offers no Context panel to open");
  });
});
