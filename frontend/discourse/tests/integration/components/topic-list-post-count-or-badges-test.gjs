import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import PostCountOrBadges from "discourse/components/topic-list/post-count-or-badges";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | topic-list/post-count-or-badges",
  function (hooks) {
    setupRenderingTest(hooks);

    test("nested topic with new replies renders the new-replies dot", async function (assert) {
      const store = this.owner.lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 1,
        is_nested_view: true,
        has_new_replies: true,
        unread_posts: 0,
      });

      await render(
        <template>
          <PostCountOrBadges @topic={{topic}} @postBadgesEnabled={{true}} />
        </template>
      );

      assert.dom(".badge-notification.new-replies").exists();
      assert.dom(".badge-notification.unread-posts").doesNotExist();
    });

    test("nested topic without new replies falls back to the post-count cell", async function (assert) {
      const store = this.owner.lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 2,
        is_nested_view: true,
        has_new_replies: false,
        unread_posts: 0,
      });

      await render(
        <template>
          <PostCountOrBadges @topic={{topic}} @postBadgesEnabled={{true}} />
        </template>
      );

      assert.dom(".badge-notification.new-replies").doesNotExist();
      assert.dom(".badge-notification.new-topic").doesNotExist();
    });

    test("nested topic does not render the unread-posts count even if unread_posts > 0", async function (assert) {
      const store = this.owner.lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 3,
        is_nested_view: true,
        has_new_replies: false,
        unread_posts: 5,
      });

      await render(
        <template>
          <PostCountOrBadges @topic={{topic}} @postBadgesEnabled={{true}} />
        </template>
      );

      assert.dom(".badge-notification.unread-posts").doesNotExist();
    });

    test("flat topic with unread_posts still renders the unread-posts count", async function (assert) {
      const store = this.owner.lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 4,
        is_nested_view: false,
        unread_posts: 3,
        unseen: false,
      });

      await render(
        <template>
          <PostCountOrBadges @topic={{topic}} @postBadgesEnabled={{true}} />
        </template>
      );

      assert.dom(".badge-notification.unread-posts").exists();
      assert.dom(".badge-notification.new-replies").doesNotExist();
    });

    test("flat topic with no unread_posts falls back to the post-count cell", async function (assert) {
      const store = this.owner.lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 5,
        is_nested_view: false,
        unread_posts: 0,
      });

      await render(
        <template>
          <PostCountOrBadges @topic={{topic}} @postBadgesEnabled={{true}} />
        </template>
      );

      assert.dom(".badge-notification.unread-posts").doesNotExist();
      assert.dom(".badge-notification.new-replies").doesNotExist();
    });
  }
);
