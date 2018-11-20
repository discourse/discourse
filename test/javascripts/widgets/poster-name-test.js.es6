import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("poster-name");

widgetTest("basic rendering", {
  template: '{{mount-widget widget="poster-name" args=args}}',
  beforeEach() {
    this.set("args", {
      username: "eviltrout",
      usernameUrl: "/u/eviltrout",
      name: "Robin Ward",
      user_title: "Trout Master"
    });
  },
  test(assert) {
    assert.ok(this.$(".names").length);
    assert.ok(this.$("span.username").length);
    assert.ok(this.$("a[data-user-card=eviltrout]").length);
    assert.equal(this.$(".username a").text(), "eviltrout");
    assert.equal(this.$(".full-name a").text(), "Robin Ward");
    assert.equal(this.$(".user-title").text(), "Trout Master");
  }
});

widgetTest("extra classes and glyphs", {
  template: '{{mount-widget widget="poster-name" args=args}}',
  beforeEach() {
    this.set("args", {
      username: "eviltrout",
      usernameUrl: "/u/eviltrout",
      staff: true,
      admin: true,
      moderator: true,
      new_user: true,
      primary_group_name: "fish"
    });
  },
  test(assert) {
    assert.ok(this.$("span.staff").length);
    assert.ok(this.$("span.admin").length);
    assert.ok(this.$("span.moderator").length);
    assert.ok(this.$(".d-icon-shield").length);
    assert.ok(this.$("span.new-user").length);
    assert.ok(this.$("span.fish").length);
  }
});

widgetTest("disable display name on posts", {
  template: '{{mount-widget widget="poster-name" args=args}}',
  beforeEach() {
    this.siteSettings.display_name_on_posts = false;
    this.set("args", { username: "eviltrout", name: "Robin Ward" });
  },
  test(assert) {
    assert.equal(this.$(".full-name").length, 0);
  }
});

widgetTest("doesn't render a name if it's similar to the username", {
  template: '{{mount-widget widget="poster-name" args=args}}',
  beforeEach() {
    this.siteSettings.prioritize_username_in_ux = true;
    this.siteSettings.display_name_on_posts = true;
    this.set("args", { username: "eviltrout", name: "evil-trout" });
  },
  test(assert) {
    assert.equal(this.$(".second").length, 0);
  }
});
