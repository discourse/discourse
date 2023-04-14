import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { getOwner } from "discourse-common/lib/get-owner";

function postStreamTest(name, attrs) {
  test(name, async function (assert) {
    this.set("posts", attrs.posts.call(this));

    await render(
      hbs`<MountWidget @widget="post-stream" @args={{hash posts=this.posts}} />`
    );

    attrs.test.call(this, assert);
  });
}

module("Integration | Component | Widget | post-stream", function (hooks) {
  setupRenderingTest(hooks);

  postStreamTest("basics", {
    posts() {
      const site = getOwner(this).lookup("service:site");
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic");
      topic.set("details.created_by", { id: 123 });

      return [
        store.createRecord("post", {
          topic,
          id: 1,
          post_number: 1,
          user_id: 123,
          primary_group_name: "trout",
          avatar_template: "/images/avatar.png",
        }),
        store.createRecord("post", {
          topic,
          id: 2,
          post_number: 2,
          post_type: site.get("post_types.moderator_action"),
        }),
        store.createRecord("post", {
          topic,
          id: 3,
          post_number: 3,
          hidden: true,
        }),
        store.createRecord("post", {
          topic,
          id: 4,
          post_number: 4,
          post_type: site.get("post_types.whisper"),
        }),
        store.createRecord("post", {
          topic,
          id: 5,
          post_number: 5,
          wiki: true,
          via_email: true,
        }),
        store.createRecord("post", {
          topic,
          id: 6,
          post_number: 6,
          via_email: true,
          is_auto_generated: true,
        }),
      ];
    },

    test(assert) {
      assert.strictEqual(count(".post-stream"), 1);
      assert.strictEqual(count(".topic-post"), 6, "renders all posts");

      // look for special class bindings
      assert.strictEqual(
        count(".topic-post:nth-of-type(1).topic-owner"),
        1,
        "it applies the topic owner class"
      );
      assert.strictEqual(
        count(".topic-post:nth-of-type(1).group-trout"),
        1,
        "it applies the primary group class"
      );
      assert.strictEqual(
        count(".topic-post:nth-of-type(1).regular"),
        1,
        "it applies the regular class"
      );
      assert.strictEqual(
        count(".topic-post:nth-of-type(2).moderator"),
        1,
        "it applies the moderator class"
      );
      assert.strictEqual(
        count(".topic-post:nth-of-type(3).post-hidden"),
        1,
        "it applies the hidden class"
      );
      assert.strictEqual(
        count(".topic-post:nth-of-type(4).whisper"),
        1,
        "it applies the whisper class"
      );
      assert.strictEqual(
        count(".topic-post:nth-of-type(5).wiki"),
        1,
        "it applies the wiki class"
      );

      // it renders an article for the body with appropriate attributes
      assert.strictEqual(count("article#post_2"), 1);
      assert.strictEqual(count('article[data-user-id="123"]'), 1);
      assert.strictEqual(count('article[data-post-id="3"]'), 1);
      assert.strictEqual(count("article#post_5.via-email"), 1);
      assert.strictEqual(count("article#post_6.is-auto-generated"), 1);

      assert.strictEqual(
        count("article:nth-of-type(1) .main-avatar"),
        1,
        "renders the main avatar"
      );
    },
  });

  postStreamTest("deleted posts", {
    posts() {
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic");
      topic.set("details.created_by", { id: 123 });

      return [
        store.createRecord("post", {
          topic,
          id: 1,
          post_number: 1,
          deleted_at: new Date().toString(),
        }),
      ];
    },

    test(assert) {
      assert.strictEqual(
        count(".topic-post.deleted"),
        1,
        "it applies the deleted class"
      );
      assert.strictEqual(
        count(".deleted-user-avatar"),
        1,
        "it has the trash avatar"
      );
    },
  });
});
