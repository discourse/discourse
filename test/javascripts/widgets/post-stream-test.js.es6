import { moduleForWidget, widgetTest } from "helpers/widget-test";
import Topic from "discourse/models/topic";
import Post from "discourse/models/post";

moduleForWidget("post-stream");

function postStreamTest(name, attrs) {
  widgetTest(name, {
    template: `{{mount-widget widget="post-stream" args=(hash posts=posts)}}`,
    beforeEach() {
      const site = this.container.lookup("site:main");
      let posts = attrs.posts.call(this);
      posts.forEach(p => p.set("site", site));
      this.set("posts", posts);
    },
    test: attrs.test
  });
}

postStreamTest("basics", {
  posts() {
    const site = this.container.lookup("site:main");
    const topic = Topic.create({ details: { created_by: { id: 123 } } });
    return [
      Post.create({
        topic,
        id: 1,
        post_number: 1,
        user_id: 123,
        primary_group_name: "trout",
        avatar_template: "/images/avatar.png"
      }),
      Post.create({
        topic,
        id: 2,
        post_number: 2,
        post_type: site.get("post_types.moderator_action")
      }),
      Post.create({ topic, id: 3, post_number: 3, hidden: true }),
      Post.create({
        topic,
        id: 4,
        post_number: 4,
        post_type: site.get("post_types.whisper")
      }),
      Post.create({
        topic,
        id: 5,
        post_number: 5,
        wiki: true,
        via_email: true
      }),
      Post.create({
        topic,
        id: 6,
        post_number: 6,
        via_email: true,
        is_auto_generated: true
      })
    ];
  },

  test(assert) {
    assert.equal(this.$(".post-stream").length, 1);
    assert.equal(this.$(".topic-post").length, 6, "renders all posts");

    // look for special class bindings
    assert.equal(
      this.$(".topic-post:eq(0).topic-owner").length,
      1,
      "it applies the topic owner class"
    );
    assert.equal(
      this.$(".topic-post:eq(0).group-trout").length,
      1,
      "it applies the primary group class"
    );
    assert.equal(
      this.$(".topic-post:eq(0).regular").length,
      1,
      "it applies the regular class"
    );
    assert.equal(
      this.$(".topic-post:eq(1).moderator").length,
      1,
      "it applies the moderator class"
    );
    assert.equal(
      this.$(".topic-post:eq(2).post-hidden").length,
      1,
      "it applies the hidden class"
    );
    assert.equal(
      this.$(".topic-post:eq(3).whisper").length,
      1,
      "it applies the whisper class"
    );
    assert.equal(
      this.$(".topic-post:eq(4).wiki").length,
      1,
      "it applies the wiki class"
    );

    // it renders an article for the body with appropriate attributes
    assert.equal(this.$("article#post_2").length, 1);
    assert.equal(this.$("article[data-user-id=123]").length, 1);
    assert.equal(this.$("article[data-post-id=3]").length, 1);
    assert.equal(this.$("article#post_5.via-email").length, 1);
    assert.equal(this.$("article#post_6.is-auto-generated").length, 1);

    assert.equal(
      this.$("article:eq(0) .main-avatar").length,
      1,
      "renders the main avatar"
    );
  }
});

postStreamTest("deleted posts", {
  posts() {
    const topic = Topic.create({ details: { created_by: { id: 123 } } });
    return [
      Post.create({
        topic,
        id: 1,
        post_number: 1,
        deleted_at: new Date().toString()
      })
    ];
  },

  test(assert) {
    assert.equal(
      this.$(".topic-post.deleted").length,
      1,
      "it applies the deleted class"
    );
    assert.equal(
      this.$(".deleted-user-avatar").length,
      1,
      "it has the trash avatar"
    );
  }
});
