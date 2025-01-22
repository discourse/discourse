import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import HomeLogo from "discourse/components/header/home-logo";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const bigLogo = "/images/d-logo-sketch.png?test";
const smallLogo = "/images/d-logo-sketch-small.png?test";
const mobileLogo = "/images/d-logo-sketch.png?mobile";
const darkLogo = "/images/d-logo-sketch.png?dark";
const title = "Cool Forum";
const prefersDark = "(prefers-color-scheme: dark)";

module("Integration | Component | home-logo", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    this.session = getOwner(this).lookup("service:session");
    this.session.set("darkModeAvailable", null);
    this.session.set("defaultColorSchemeIsDark", null);
  });

  test("basics", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.siteSettings.title = title;

    await render(<template><HomeLogo @minimized={{false}} /></template>);
    assert.dom(".title").exists({ count: 1 });
    assert.dom("img#site-logo.logo-big").exists({ count: 1 });
    assert.dom("#site-logo").hasAttribute("src", bigLogo);
    assert.dom("#site-logo").hasAttribute("alt", title);
  });

  test("basics - minimized", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.siteSettings.title = title;

    await render(<template><HomeLogo @minimized={{true}} /></template>);
    assert.dom("img.logo-small").exists({ count: 1 });
    assert.dom("img.logo-small").hasAttribute("src", smallLogo);
    assert.dom("img.logo-small").hasAttribute("alt", title);
    assert.dom("img.logo-small").hasAttribute("width", "36");
  });

  test("no logo", async function (assert) {
    this.siteSettings.site_logo_url = "";
    this.siteSettings.site_logo_small_url = "";
    this.siteSettings.title = title;

    await render(<template><HomeLogo @minimized={{false}} /></template>);
    assert.dom("h1#site-text-logo.text-logo").exists({ count: 1 });
    assert.dom("#site-text-logo").hasText(title, "has title as text logo");
  });

  test("no logo - minimized", async function (assert) {
    this.siteSettings.site_logo_url = "";
    this.siteSettings.site_logo_small_url = "";
    this.siteSettings.title = title;

    await render(<template><HomeLogo @minimized={{true}} /></template>);
    assert.dom(".d-icon-house").exists({ count: 1 });
  });

  test("mobile logo", async function (assert) {
    this.siteSettings.site_mobile_logo_url = mobileLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.site.mobileView = true;

    await render(<template><HomeLogo /></template>);
    assert.dom("img#site-logo.logo-mobile").exists({ count: 1 });
    assert.dom("#site-logo").hasAttribute("src", mobileLogo);
  });

  test("mobile without logo", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.site.mobileView = true;

    await render(<template><HomeLogo /></template>);
    assert.dom("img#site-logo.logo-big").exists({ count: 1 });
    assert.dom("#site-logo").hasAttribute("src", bigLogo);
  });

  test("logo with dark mode alternative", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
    this.session.set("darkModeAvailable", true);

    await render(<template><HomeLogo /></template>);
    assert.dom("img#site-logo.logo-big").exists({ count: 1 });
    assert.dom("#site-logo").hasAttribute("src", bigLogo);
    assert
      .dom("picture source")
      .hasAttribute("media", prefersDark, "includes dark mode media attribute");
    assert
      .dom("picture source")
      .hasAttribute(
        "srcset",
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

    await render(<template><HomeLogo /></template>);

    assert.dom("#site-logo").hasAttribute("src", mobileLogo);
    assert
      .dom("picture source")
      .hasAttribute("media", prefersDark, "includes dark mode media attribute");
    assert
      .dom("picture source")
      .hasAttribute(
        "srcset",
        darkLogo,
        "includes dark mode alternative logo source"
      );
  });

  test("dark mode enabled but no dark logo set", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = "";
    this.session.set("darkModeAvailable", true);

    await render(<template><HomeLogo /></template>);
    assert.dom("img#site-logo.logo-big").exists({ count: 1 });
    assert.dom("#site-logo").hasAttribute("src", bigLogo);
    assert.dom("picture").doesNotExist("does not include alternative logo");
  });

  test("dark logo set but no dark mode", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;

    await render(<template><HomeLogo /></template>);
    assert.dom("img#site-logo.logo-big").exists({ count: 1 });
    assert.dom("#site-logo").hasAttribute("src", bigLogo);
    assert.dom("picture").doesNotExist("does not include alternative logo");
  });

  test("dark color scheme and dark logo set", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
    this.session.set("defaultColorSchemeIsDark", true);

    await render(<template><HomeLogo /></template>);
    assert.dom("img#site-logo.logo-big").exists({ count: 1 });
    assert.dom("#site-logo").hasAttribute("src", darkLogo, "uses dark logo");
    assert.dom("picture").doesNotExist("does not add dark mode alternative");
  });

  test("dark color scheme and dark logo not set", async function (assert) {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = "";
    this.session.set("defaultColorSchemeIsDark", true);

    await render(<template><HomeLogo /></template>);
    assert.dom("img#site-logo.logo-big").exists({ count: 1 });
    assert
      .dom("#site-logo")
      .hasAttribute(
        "src",
        bigLogo,
        "uses regular logo on dark scheme if no dark logo"
      );
  });

  test("the home logo href url defaults to /", async function (assert) {
    await render(<template><HomeLogo @minimized={{false}} /></template>);

    assert.dom(".title a").hasAttribute("href", "/", "home logo href equals /");
  });

  test("api.registerHomeLogoHrefCallback can be used to change the logo href url", async function (assert) {
    withPluginApi("1.32.0", (api) => {
      api.registerHomeLogoHrefCallback(() => "https://example.com");
    });

    await render(<template><HomeLogo @minimized={{false}} /></template>);

    assert
      .dom(".title a")
      .hasAttribute(
        "href",
        "https://example.com",
        "home logo href equals the one set by the callback"
      );
  });
});
