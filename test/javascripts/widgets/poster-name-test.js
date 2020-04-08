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
    assert.ok(find(".names").length);
    assert.ok(find("span.username").length);
    assert.ok(find("a[data-user-card=eviltrout]").length);
    assert.equal(find(".username a").text(), "eviltrout");
    assert.equal(find(".full-name a").text(), "Robin Ward");
    assert.equal(find(".user-title").text(), "Trout Master");
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
    assert.ok(find("span.staff").length);
    assert.ok(find("span.admin").length);
    assert.ok(find("span.moderator").length);
    assert.ok(find(".d-icon-shield-alt").length);
    assert.ok(find("span.new-user").length);
    assert.ok(find("span.fish").length);
  }
});

widgetTest("disable display name on posts", {
  template: '{{mount-widget widget="poster-name" args=args}}',
  beforeEach() {
    this.siteSettings.display_name_on_posts = false;
    this.set("args", { username: "eviltrout", name: "Robin Ward" });
  },
  test(assert) {
    assert.equal(find(".full-name").length, 0);
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
    assert.equal(find(".second").length, 0);
  }
});
