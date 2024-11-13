import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { resetPostMenuExtraButtons } from "discourse/widgets/post-menu";
import { withSilencedDeprecations } from "discourse-common/lib/deprecated";

function postStreamTest(name, attrs) {
  test(name, async function (assert) {
    this.set("posts", attrs.posts.call(this));

    await render(
      hbs`<MountWidget @widget="post-stream" @args={{hash posts=this.posts}} />`
    );

    attrs.test.call(this, assert);
  });
}

let lastTransformedPost = null;

module("Integration | Component | Widget | post-stream", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetPostMenuExtraButtons();
  });

  postStreamTest("extensibility", {
    posts() {
      withPluginApi("0.14.0", (api) => {
        withSilencedDeprecations("discourse.post-menu-widget-overrides", () => {
          api.addPostMenuButton("coffee", (transformedPost) => {
            lastTransformedPost = transformedPost;
            return {
              action: "drinkCoffee",
              icon: "mug-saucer",
              className: "hot-coffee",
              title: "coffee.title",
              position: "first",
            };
          });
        });
      });

      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic");
      topic.set("details.created_by", { id: 123 });
      topic.set("id", 1234);

      return [
        store.createRecord("post", {
          topic,
          id: 1,
          post_number: 1,
          user_id: 123,
          primary_group_name: "trout",
          avatar_template: "/images/avatar.png",
        }),
      ];
    },

    test(assert) {
      assert.dom(".post-stream").exists({ count: 1 });
      assert.dom(".topic-post").exists({ count: 1 }, "renders all posts");
      assert.notStrictEqual(lastTransformedPost, null, "it transforms posts");
      assert.strictEqual(
        lastTransformedPost.topic.id,
        1234,
        "it also transforms the topic"
      );
      assert
        .dom(".actions .extra-buttons .hot-coffee")
        .exists({ count: 1 }, "has the extended button");
    },
  });

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
      assert.dom(".post-stream").exists({ count: 1 });
      assert.dom(".topic-post").exists({ count: 6 }, "renders all posts");

      // look for special class bindings
      assert
        .dom(".topic-post:nth-of-type(1).topic-owner")
        .exists({ count: 1 }, "applies the topic owner class");
      assert
        .dom(".topic-post:nth-of-type(1).group-trout")
        .exists({ count: 1 }, "applies the primary group class");
      assert
        .dom(".topic-post:nth-of-type(1).regular")
        .exists({ count: 1 }, "applies the regular class");
      assert
        .dom(".topic-post:nth-of-type(2).moderator")
        .exists({ count: 1 }, "applies the moderator class");
      assert
        .dom(".topic-post:nth-of-type(3).post-hidden")
        .exists({ count: 1 }, "applies the hidden class");
      assert
        .dom(".topic-post:nth-of-type(4).whisper")
        .exists({ count: 1 }, "applies the whisper class");
      assert
        .dom(".topic-post:nth-of-type(5).wiki")
        .exists({ count: 1 }, "applies the wiki class");

      // it renders an article for the body with appropriate attributes
      assert.dom("article#post_2").exists({ count: 1 });
      assert.dom('article[data-user-id="123"]').exists({ count: 1 });
      assert.dom('article[data-post-id="3"]').exists({ count: 1 });
      assert.dom("article#post_5.via-email").exists({ count: 1 });
      assert.dom("article#post_6.is-auto-generated").exists({ count: 1 });

      assert
        .dom("article:nth-of-type(1) .main-avatar")
        .exists({ count: 1 }, "renders the main avatar");
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
      assert
        .dom(".topic-post.deleted")
        .exists({ count: 1 }, "applies the deleted class");
      assert
        .dom(".deleted-user-avatar")
        .exists({ count: 1 }, "has the trash avatar");
    },
  });
});
