import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("home-logo");

const bigLogo = "/images/d-logo-sketch.png?test";
const smallLogo = "/images/d-logo-sketch-small.png?test";
const mobileLogo = "/images/d-logo-sketch.png?mobile";
const title = "Cool Forum";

widgetTest("basics", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.logo_url = bigLogo;
    this.siteSettings.logo_small_url = smallLogo;
    this.siteSettings.title = title;
    this.set("args", { minimized: false });
  },

  test(assert) {
    assert.ok(this.$(".title").length === 1);

    assert.ok(this.$("img#site-logo.logo-big").length === 1);
    assert.equal(this.$("#site-logo").attr("src"), bigLogo);
    assert.equal(this.$("#site-logo").attr("alt"), title);
  }
});

widgetTest("basics - minimized", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.logo_url = bigLogo;
    this.siteSettings.logo_small_url = smallLogo;
    this.siteSettings.title = title;
    this.set("args", { minimized: true });
  },

  test(assert) {
    assert.ok(this.$("img.logo-small").length === 1);
    assert.equal(this.$("img.logo-small").attr("src"), smallLogo);
    assert.equal(this.$("img.logo-small").attr("alt"), title);
  }
});

widgetTest("no logo", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.logo_url = "";
    this.siteSettings.logo_small_url = "";
    this.siteSettings.title = title;
    this.set("args", { minimized: false });
  },

  test(assert) {
    assert.ok(this.$("h1#site-text-logo.text-logo").length === 1);
    assert.equal(this.$("#site-text-logo").text(), title);
  }
});

widgetTest("no logo - minimized", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.logo_url = "";
    this.siteSettings.logo_small_url = "";
    this.siteSettings.title = title;
    this.set("args", { minimized: true });
  },

  test(assert) {
    assert.ok(this.$(".d-icon-home").length === 1);
  }
});

widgetTest("mobile logo", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.mobile_logo_url = mobileLogo;
    this.siteSettings.logo_small_url = smallLogo;
    this.site.mobileView = true;
  },

  test(assert) {
    assert.ok(this.$("img#site-logo.logo-big").length === 1);
    assert.equal(this.$("#site-logo").attr("src"), mobileLogo);
  }
});

widgetTest("mobile without logo", {
  template: '{{mount-widget widget="home-logo" args=args}}',
  beforeEach() {
    this.siteSettings.logo_url = bigLogo;
    this.site.mobileView = true;
  },

  test(assert) {
    assert.ok(this.$("img#site-logo.logo-big").length === 1);
    assert.equal(this.$("#site-logo").attr("src"), bigLogo);
  }
});
