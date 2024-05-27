// deprecated in favor of discourse/tests/integration/components/home-logo-test.gjs
import { getOwner } from "@ember/application";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { clearHomeLogoHrefCallback as clearComponentHomeLogoHrefCallback } from "discourse/components/header/home-logo";
import MountWidget from "discourse/components/mount-widget";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count, exists, query } from "discourse/tests/helpers/qunit-helpers";
import { clearHomeLogoHrefCallback as clearWidgetHomeLogoHrefCallback } from "discourse/widgets/home-logo";

const bigLogo = "/images/d-logo-sketch.png?test";
const smallLogo = "/images/d-logo-sketch-small.png?test";
const mobileLogo = "/images/d-logo-sketch.png?mobile";
const darkLogo = "/images/d-logo-sketch.png?dark";
const title = "Cool Forum";
const prefersDark = "(prefers-color-scheme: dark)";

module("Integration | Component | Widget | home-logo", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    this.session = getOwner(this).lookup("service:session");
    this.session.set("darkModeAvailable", null);
    this.session.set("defaultColorSchemeIsDark", null);
    clearWidgetHomeLogoHrefCallback();
    clearComponentHomeLogoHrefCallback();
  });

  test("basics", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.siteSettings.title = title;
    const args = { minimized: false };

    await render(<template>
      <MountWidget @widget="home-logo" @args={{args}} />
    </template>);

    assert.strictEqual(count(".title"), 1);
    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);
    assert.strictEqual(query("#site-logo").getAttribute("alt"), title);
  });

  test("basics - minimized", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.siteSettings.title = title;
    const args = { minimized: true };

    await render(<template>
      <MountWidget @widget="home-logo" @args={{args}} />
    </template>);

    assert.strictEqual(count("img.logo-small"), 1);
    assert.strictEqual(query("img.logo-small").getAttribute("src"), smallLogo);
    assert.strictEqual(query("img.logo-small").getAttribute("alt"), title);
    assert.strictEqual(query("img.logo-small").getAttribute("width"), "36");
  });

  test("no logo", async function (assert) {
    this.siteSettings.site_logo_url = "";
    this.siteSettings.site_logo_small_url = "";
    this.siteSettings.title = title;
    const args = { minimized: false };

    await render(<template>
      <MountWidget @widget="home-logo" @args={{args}} />
    </template>);

    assert.strictEqual(count("h1#site-text-logo.text-logo"), 1);
    assert.strictEqual(query("#site-text-logo").innerText, title);
  });

  test("no logo - minimized", async function (assert) {
    this.siteSettings.site_logo_url = "";
    this.siteSettings.site_logo_small_url = "";
    this.siteSettings.title = title;
    const args = { minimized: true };

    await render(<template>
      <MountWidget @widget="home-logo" @args={{args}} />
    </template>);

    assert.strictEqual(count(".d-icon-home"), 1);
  });

  test("mobile logo", async function (assert) {
    this.siteSettings.site_mobile_logo_url = mobileLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.site.mobileView = true;

    await render(<template><MountWidget @widget="home-logo" /></template>);

    assert.strictEqual(count("img#site-logo.logo-mobile"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), mobileLogo);
  });

  test("mobile without logo", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.site.mobileView = true;

    await render(<template><MountWidget @widget="home-logo" /></template>);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);
  });

  test("logo with dark mode alternative", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
    this.session.set("darkModeAvailable", true);

    await render(<template><MountWidget @widget="home-logo" /></template>);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);

    assert.strictEqual(
      query("picture source").getAttribute("media"),
      prefersDark,
      "includes dark mode media attribute"
    );
    assert.strictEqual(
      query("picture source").getAttribute("srcset"),
      darkLogo,
      "includes dark mode alternative logo source"
    );
  });

  test("mobile logo with dark mode alternative", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_mobile_logo_url = mobileLogo;
    this.siteSettings.site_mobile_logo_dark_url = darkLogo;
    this.session.set("darkModeAvailable", true);

    this.site.mobileView = true;

    await render(<template><MountWidget @widget="home-logo" /></template>);

    assert.strictEqual(query("#site-logo").getAttribute("src"), mobileLogo);

    assert.strictEqual(
      query("picture source").getAttribute("media"),
      prefersDark,
      "includes dark mode media attribute"
    );
    assert.strictEqual(
      query("picture source").getAttribute("srcset"),
      darkLogo,
      "includes dark mode alternative logo source"
    );
  });

  test("dark mode enabled but no dark logo set", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = "";
    this.session.set("darkModeAvailable", true);

    await render(<template><MountWidget @widget="home-logo" /></template>);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);
    assert.ok(!exists("picture"), "does not include alternative logo");
  });

  test("dark logo set but no dark mode", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;

    await render(<template><MountWidget @widget="home-logo" /></template>);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);
    assert.ok(!exists("picture"), "does not include alternative logo");
  });

  test("dark color scheme and dark logo set", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
    this.session.set("defaultColorSchemeIsDark", true);

    await render(<template><MountWidget @widget="home-logo" /></template>);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(
      query("#site-logo").getAttribute("src"),
      darkLogo,
      "uses dark logo"
    );
    assert.ok(!exists("picture"), "does not add dark mode alternative");
  });

  test("dark color scheme and dark logo not set", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = "";
    this.session.set("defaultColorSchemeIsDark", true);

    await render(<template><MountWidget @widget="home-logo" /></template>);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(
      query("#site-logo").getAttribute("src"),
      bigLogo,
      "uses regular logo on dark scheme if no dark logo"
    );
  });

  test("the home logo href url defaults to /", async function (assert) {
    await render(<template><MountWidget @widget="home-logo" /></template>);

    const anchorElement = query("#site-logo").closest("a");
    assert.strictEqual(
      anchorElement.getAttribute("href"),
      "/",
      "home logo href equals /"
    );
  });

  test("api.registerHomeLogoHrefCallback can be used to change the logo href url", async function (assert) {
    withPluginApi("1.32.0", (api) => {
      api.registerHomeLogoHrefCallback(() => "https://example.com");
    });

    await render(<template><MountWidget @widget="home-logo" /></template>);

    const anchorElement = query("#site-logo").closest("a");
    assert.strictEqual(
      anchorElement.getAttribute("href"),
      "https://example.com",
      "home logo href equals the one set by the callback"
    );
  });
});
