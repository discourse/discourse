import {
  moduleForWidget,
  widgetTest,
} from "discourse/tests/helpers/widget-test";
import Session from "discourse/models/session";
moduleForWidget("home-logo");

const bigLogo = "/images/d-logo-sketch.png?test";
const smallLogo = "/images/d-logo-sketch-small.png?test";
const mobileLogo = "/images/d-logo-sketch.png?mobile";
const darkLogo = "/images/d-logo-sketch.png?dark";
const title = "Cool Forum";
const prefersDark = "(prefers-color-scheme: dark)";

widgetTest("basics", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  skip: true,
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.siteSettings.title = title;
    this.set("args", { minimized: false });
  },

  test(assert) {
    assert.ok(find(".title").length === 1);

    assert.ok(find("img#site-logo.logo-big").length === 1);
    assert.equal(find("#site-logo").attr("src"), bigLogo);
    assert.equal(find("#site-logo").attr("alt"), title);
  },
});

widgetTest("basics - minimized", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.siteSettings.title = title;
    this.set("args", { minimized: true });
  },

  test(assert) {
    assert.ok(find("img.logo-small").length === 1);
    assert.equal(find("img.logo-small").attr("src"), smallLogo);
    assert.equal(find("img.logo-small").attr("alt"), title);
    assert.equal(find("img.logo-small").attr("width"), 36);
  },
});

widgetTest("no logo", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = "";
    this.siteSettings.site_logo_small_url = "";
    this.siteSettings.title = title;
    this.set("args", { minimized: false });
  },

  test(assert) {
    assert.ok(find("h1#site-text-logo.text-logo").length === 1);
    assert.equal(find("#site-text-logo").text(), title);
  },
});

widgetTest("no logo - minimized", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = "";
    this.siteSettings.site_logo_small_url = "";
    this.siteSettings.title = title;
    this.set("args", { minimized: true });
  },

  test(assert) {
    assert.ok(find(".d-icon-home").length === 1);
  },
});

widgetTest("mobile logo", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_mobile_logo_url = mobileLogo;
    this.siteSettings.site_logo_small_url = smallLogo;
    this.site.mobileView = true;
  },

  test(assert) {
    assert.ok(find("img#site-logo.logo-mobile").length === 1);
    assert.equal(find("#site-logo").attr("src"), mobileLogo);
  },
});

widgetTest("mobile without logo", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.site.mobileView = true;
  },

  test(assert) {
    assert.ok(find("img#site-logo.logo-big").length === 1);
    assert.equal(find("#site-logo").attr("src"), bigLogo);
  },
});

widgetTest("logo with dark mode alternative", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
    Session.currentProp("darkModeAvailable", true);
  },
  afterEach() {
    Session.currentProp("darkModeAvailable", null);
  },

  test(assert) {
    assert.ok(find("img#site-logo.logo-big").length === 1);
    assert.equal(find("#site-logo").attr("src"), bigLogo);

    assert.equal(
      find("picture source").attr("media"),
      prefersDark,
      "includes dark mode media attribute"
    );
    assert.equal(
      find("picture source").attr("srcset"),
      darkLogo,
      "includes dark mode alternative logo source"
    );
  },
});

widgetTest("mobile logo with dark mode alternative", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_mobile_logo_url = mobileLogo;
    this.siteSettings.site_mobile_logo_dark_url = darkLogo;
    Session.currentProp("darkModeAvailable", true);

    this.site.mobileView = true;
  },
  afterEach() {
    Session.currentProp("darkModeAvailable", null);
  },

  test(assert) {
    assert.equal(find("#site-logo").attr("src"), mobileLogo);

    assert.equal(
      find("picture source").attr("media"),
      prefersDark,
      "includes dark mode media attribute"
    );
    assert.equal(
      find("picture source").attr("srcset"),
      darkLogo,
      "includes dark mode alternative logo source"
    );
  },
});

widgetTest("dark mode enabled but no dark logo set", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = "";
    Session.currentProp("darkModeAvailable", true);
  },
  afterEach() {
    Session.currentProp("darkModeAvailable", null);
  },

  test(assert) {
    assert.ok(find("img#site-logo.logo-big").length === 1);
    assert.equal(find("#site-logo").attr("src"), bigLogo);
    assert.ok(
      find("picture").length === 0,
      "does not include alternative logo"
    );
  },
});

widgetTest("dark logo set but no dark mode", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
  },

  test(assert) {
    assert.ok(find("img#site-logo.logo-big").length === 1);
    assert.equal(find("#site-logo").attr("src"), bigLogo);
    assert.ok(
      find("picture").length === 0,
      "does not include alternative logo"
    );
  },
});

widgetTest("dark color scheme and dark logo set", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = darkLogo;
    Session.currentProp("defaultColorSchemeIsDark", true);
  },
  afterEach() {
    Session.currentProp("defaultColorSchemeIsDark", null);
  },
  test(assert) {
    assert.ok(find("img#site-logo.logo-big").length === 1);
    assert.equal(find("#site-logo").attr("src"), darkLogo, "uses dark logo");
    assert.ok(
      find("picture").length === 0,
      "does not add dark mode alternative"
    );
  },
});

widgetTest("dark color scheme and dark logo not set", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.site_logo_url = bigLogo;
    this.siteSettings.site_logo_dark_url = "";
    Session.currentProp("defaultColorSchemeIsDark", true);
  },
  afterEach() {
    Session.currentProp("defaultColorSchemeIsDark", null);
  },
  test(assert) {
    assert.ok(find("img#site-logo.logo-big").length === 1);
    assert.equal(
      find("#site-logo").attr("src"),
      bigLogo,
      "uses regular logo on dark scheme if no dark logo"
    );
  },
});
