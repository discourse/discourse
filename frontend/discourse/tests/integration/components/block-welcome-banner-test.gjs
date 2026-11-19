import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import WelcomeBanner from "discourse/blocks/builtin/welcome-banner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

function renderBanner(args = {}) {
  withPluginApi((api) =>
    api.renderBlocks("hero-blocks", [{ block: WelcomeBanner, args }])
  );
}

module("Integration | Blocks | welcome-banner", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("falls back to the welcome banner's text and shows search", async function (assert) {
    this.currentUser.previous_visit_at = new Date("2025-01-01");
    renderBanner();

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-welcome-banner .welcome-banner__title").containsText(
      i18n("welcome_banner.header.logged_in_members", {
        preferred_display_name: "eviltrout",
      })
    );
    assert
      .dom(".d-block-welcome-banner #welcome-banner-search-input")
      .hasAttribute("placeholder", i18n("welcome_banner.search_placeholder"));
    assert
      .dom(".d-block-welcome-banner__backdrop img")
      .doesNotExist("there's no background image by default");
  });

  test("fills the variables into author text and escapes it", async function (assert) {
    this.currentUser.previous_visit_at = null;
    this.siteSettings.title = "Tide Pool";
    renderBanner({
      headerNewMembers:
        "<b>Hi</b> %{preferred_display_name}, meet %{site_name}",
      subheaderLoggedInMembers: "Glad you're here",
    });

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-welcome-banner .welcome-banner__title")
      .containsText("<b>Hi</b> eviltrout, meet Tide Pool");
    assert
      .dom(".d-block-welcome-banner .welcome-banner__title b")
      .doesNotExist("author markup is shown as text");
    assert
      .dom(".d-block-welcome-banner .welcome-banner__subheader")
      .hasText("Glad you're here");
  });

  test("hides search when it's turned off", async function (assert) {
    renderBanner({ showSearch: false });

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-welcome-banner").exists();
    assert.dom(".d-block-welcome-banner .search-menu").doesNotExist();
  });

  test("uses the author's search placeholder", async function (assert) {
    renderBanner({ searchPlaceholder: "Find a thread" });

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom("#welcome-banner-search-input")
      .hasAttribute("placeholder", "Find a thread")
      .hasAttribute("aria-label", "Find a thread");
  });

  test("renders the background image behind the text", async function (assert) {
    renderBanner({
      backgroundImage: { url: "/images/discourse-logo-sketch.png" },
    });

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-welcome-banner.--with-bg-img").exists();
    assert
      .dom(".d-block-welcome-banner__backdrop img")
      .hasAttribute("src", /discourse-logo-sketch\.png/);
  });
});

module("Integration | Blocks | welcome-banner | Anonymous", function (hooks) {
  setupRenderingTest(hooks, { anonymous: true });

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("greets visitors with the anonymous text", async function (assert) {
    this.siteSettings.title = "Tide Pool";
    renderBanner({
      headerLoggedInMembers: "Welcome back",
      headerAnonymousMembers: "Hello from %{site_name}",
      subheaderAnonymousMembers: "Have a look around",
    });

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-welcome-banner .welcome-banner__title")
      .containsText("Hello from Tide Pool");
    assert
      .dom(".d-block-welcome-banner .welcome-banner__subheader")
      .hasText("Have a look around");
  });
});
