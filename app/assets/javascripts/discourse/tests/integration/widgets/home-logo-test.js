import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import Session from "discourse/models/session";
import hbs from "htmlbars-inline-precompile";

const bigLogo = "/images/d-logo-sketch.png?test";
const smallLogo = "/images/d-logo-sketch-small.png?test";
const mobileLogo = "/images/d-logo-sketch.png?mobile";
const darkLogo = "/images/d-logo-sketch.png?dark";
const title = "Cool Forum";
const prefersDark = "(prefers-color-scheme: dark)";

discourseModule(
  "Integration | Component | Widget | home-logo",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("basics", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = bigLogo;
        this.siteSettings.site_logo_small_url = smallLogo;
        this.siteSettings.title = title;
        this.set("args", { minimized: false });
      },

      test(assert) {
        assert.strictEqual(count(".title"), 1);

        assert.strictEqual(count("img#site-logo.logo-big"), 1);
        assert.strictEqual(queryAll("#site-logo").attr("src"), bigLogo);
        assert.strictEqual(queryAll("#site-logo").attr("alt"), title);
      },
    });

    componentTest("basics - minimized", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = bigLogo;
        this.siteSettings.site_logo_small_url = smallLogo;
        this.siteSettings.title = title;
        this.set("args", { minimized: true });
      },

      test(assert) {
        assert.strictEqual(count("img.logo-small"), 1);
        assert.strictEqual(queryAll("img.logo-small").attr("src"), smallLogo);
        assert.strictEqual(queryAll("img.logo-small").attr("alt"), title);
        assert.strictEqual(queryAll("img.logo-small").attr("width"), "36");
      },
    });

    componentTest("no logo", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = "";
        this.siteSettings.site_logo_small_url = "";
        this.siteSettings.title = title;
        this.set("args", { minimized: false });
      },

      test(assert) {
        assert.strictEqual(count("h1#site-text-logo.text-logo"), 1);
        assert.strictEqual(queryAll("#site-text-logo").text(), title);
      },
    });

    componentTest("no logo - minimized", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = "";
        this.siteSettings.site_logo_small_url = "";
        this.siteSettings.title = title;
        this.set("args", { minimized: true });
      },

      test(assert) {
        assert.strictEqual(count(".d-icon-home"), 1);
      },
    });

    componentTest("mobile logo", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_mobile_logo_url = mobileLogo;
        this.siteSettings.site_logo_small_url = smallLogo;
        this.site.mobileView = true;
      },

      test(assert) {
        assert.strictEqual(count("img#site-logo.logo-mobile"), 1);
        assert.strictEqual(queryAll("#site-logo").attr("src"), mobileLogo);
      },
    });

    componentTest("mobile without logo", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = bigLogo;
        this.site.mobileView = true;
      },

      test(assert) {
        assert.strictEqual(count("img#site-logo.logo-big"), 1);
        assert.strictEqual(queryAll("#site-logo").attr("src"), bigLogo);
      },
    });

    componentTest("logo with dark mode alternative", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = bigLogo;
        this.siteSettings.site_logo_dark_url = darkLogo;
        Session.currentProp("darkModeAvailable", true);
      },
      afterEach() {
        Session.currentProp("darkModeAvailable", null);
      },

      test(assert) {
        assert.strictEqual(count("img#site-logo.logo-big"), 1);
        assert.strictEqual(queryAll("#site-logo").attr("src"), bigLogo);

        assert.strictEqual(
          queryAll("picture source").attr("media"),
          prefersDark,
          "includes dark mode media attribute"
        );
        assert.strictEqual(
          queryAll("picture source").attr("srcset"),
          darkLogo,
          "includes dark mode alternative logo source"
        );
      },
    });

    componentTest("mobile logo with dark mode alternative", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
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
        assert.strictEqual(queryAll("#site-logo").attr("src"), mobileLogo);

        assert.strictEqual(
          queryAll("picture source").attr("media"),
          prefersDark,
          "includes dark mode media attribute"
        );
        assert.strictEqual(
          queryAll("picture source").attr("srcset"),
          darkLogo,
          "includes dark mode alternative logo source"
        );
      },
    });

    componentTest("dark mode enabled but no dark logo set", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = bigLogo;
        this.siteSettings.site_logo_dark_url = "";
        Session.currentProp("darkModeAvailable", true);
      },
      afterEach() {
        Session.currentProp("darkModeAvailable", null);
      },

      test(assert) {
        assert.strictEqual(count("img#site-logo.logo-big"), 1);
        assert.strictEqual(queryAll("#site-logo").attr("src"), bigLogo);
        assert.ok(!exists("picture"), "does not include alternative logo");
      },
    });

    componentTest("dark logo set but no dark mode", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = bigLogo;
        this.siteSettings.site_logo_dark_url = darkLogo;
      },

      test(assert) {
        assert.strictEqual(count("img#site-logo.logo-big"), 1);
        assert.strictEqual(queryAll("#site-logo").attr("src"), bigLogo);
        assert.ok(!exists("picture"), "does not include alternative logo");
      },
    });

    componentTest("dark color scheme and dark logo set", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = bigLogo;
        this.siteSettings.site_logo_dark_url = darkLogo;
        Session.currentProp("defaultColorSchemeIsDark", true);
      },
      afterEach() {
        Session.currentProp("defaultColorSchemeIsDark", null);
      },
      test(assert) {
        assert.strictEqual(count("img#site-logo.logo-big"), 1);
        assert.strictEqual(
          queryAll("#site-logo").attr("src"),
          darkLogo,
          "uses dark logo"
        );
        assert.ok(!exists("picture"), "does not add dark mode alternative");
      },
    });

    componentTest("dark color scheme and dark logo not set", {
      template: hbs`{{mount-widget widget="home-logo" args=args}}`,
      beforeEach() {
        this.siteSettings.site_logo_url = bigLogo;
        this.siteSettings.site_logo_dark_url = "";
        Session.currentProp("defaultColorSchemeIsDark", true);
      },
      afterEach() {
        Session.currentProp("defaultColorSchemeIsDark", null);
      },
      test(assert) {
        assert.strictEqual(count("img#site-logo.logo-big"), 1);
        assert.strictEqual(
          queryAll("#site-logo").attr("src"),
          bigLogo,
          "uses regular logo on dark scheme if no dark logo"
        );
      },
    });
  }
);
