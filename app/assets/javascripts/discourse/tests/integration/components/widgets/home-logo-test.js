import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count, exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import Session from "discourse/models/session";

const bigLogo = "/images/d-logo-sketch.png?test";
const smallLogo = "/images/d-logo-sketch-small.png?test";
const mobileLogo = "/images/d-logo-sketch.png?mobile";
const darkLogo = "/images/d-logo-sketch.png?dark";
const title = "Cool Forum";
const prefersDark = "(prefers-color-scheme: dark)";

module("Integration | Component | Widget | home-logo", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    Session.currentProp("darkModeAvailable", null);
    Session.currentProp("defaultColorSchemeIsDark", null);
  });

  test("basics", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.siteSettings.title = title;
    this.set("args", { minimized: false });

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count(".title"), 1);
    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);
    assert.strictEqual(query("#site-logo").getAttribute("alt"), title);
  });

  test("basics - minimized", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.siteSettings.title = title;
    this.set("args", { minimized: true });

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count("img.logo-small"), 1);
    assert.strictEqual(query("img.logo-small").getAttribute("src"), smallLogo);
    assert.strictEqual(query("img.logo-small").getAttribute("alt"), title);
    assert.strictEqual(query("img.logo-small").getAttribute("width"), "36");
  });

  test("no logo", async function (assert) {
    this.siteSettings.site_logo_url = "";
    this.siteSettings.site_logo_small_url = "";
    this.siteSettings.title = title;
    this.set("args", { minimized: false });

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count("h1#site-text-logo.text-logo"), 1);
    assert.strictEqual(query("#site-text-logo").innerText, title);
  });

  test("no logo - minimized", async function (assert) {
    this.siteSettings.site_logo_url = "";
    this.siteSettings.site_logo_small_url = "";
    this.siteSettings.title = title;
    this.set("args", { minimized: true });

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count(".d-icon-home"), 1);
  });

  test("mobile logo", async function (assert) {
    this.siteSettings.site_mobile_logo_url = mobileLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.site.mobileView = true;

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count("img#site-logo.logo-mobile"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), mobileLogo);
  });

  test("mobile without logo", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.site.mobileView = true;

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);
  });

  test("logo with dark mode alternative", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
    Session.currentProp("darkModeAvailable", true);

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

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
    Session.currentProp("darkModeAvailable", true);

    this.site.mobileView = true;

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

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
    Session.currentProp("darkModeAvailable", true);

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);
    assert.ok(!exists("picture"), "does not include alternative logo");
  });

  test("dark logo set but no dark mode", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(query("#site-logo").getAttribute("src"), bigLogo);
    assert.ok(!exists("picture"), "does not include alternative logo");
  });

  test("dark color scheme and dark logo set", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
    Session.currentProp("defaultColorSchemeIsDark", true);

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

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
    Session.currentProp("defaultColorSchemeIsDark", true);

    await render(hbs`<MountWidget @widget="home-logo" @args={{this.args}} />`);

    assert.strictEqual(count("img#site-logo.logo-big"), 1);
    assert.strictEqual(
      query("#site-logo").getAttribute("src"),
      bigLogo,
      "uses regular logo on dark scheme if no dark logo"
    );
  });
});
