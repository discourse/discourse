import { moduleForWidget, widgetTest } from "helpers/widget-test";

moduleForWidget("topic-participant");

widgetTest("one post", {
  template: '{{mount-widget widget="topic-participant" args=args}}',

  beforeEach() {
    this.set("args", {
      username: "test",
      avatar_template: "/images/avatar.png",
      post_count: 1
    });
  },

  test(assert) {
    assert.ok(exists("a.poster.trigger-user-card"));
    assert.ok(!exists("span.post-count"), "don't show count for only 1 post");
    assert.ok(!exists(".avatar-flair"), "no avatar flair");
  }
});

widgetTest("many posts, a primary group with flair", {
  template: '{{mount-widget widget="topic-participant" args=args}}',

  beforeEach() {
    this.set("args", {
      username: "test",
      avatar_template: "/images/avatar.png",
      post_count: 5,
      primary_group_name: "devs",
      primary_group_flair_url: "/images/d-logo-sketch-small.png",
      primary_group_flair_bg_color: "222"
    });
  },

  test(assert) {
    assert.ok(exists("a.poster.trigger-user-card"));
    assert.ok(exists("span.post-count"), "show count for many posts");
    assert.ok(
      exists(".group-devs a.poster"),
      "add class for the group outside the link"
    );
    assert.ok(
      exists(".avatar-flair.avatar-flair-devs"),
      "show flair with group class"
    );
  }
});
