import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicPostBadges from "discourse/components/topic-post-badges";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | TopicPostBadges", function (hooks) {
  setupRenderingTest(hooks);

  test("keeps the unread count as the accessible name", async function (assert) {
    await render(
      <template><TopicPostBadges @unreadPosts={{5}} @url="/t/1/2" /></template>
    );

    const link = ".badge-notification.unread-posts";
    assert.dom(link).hasText("5", "the visible count is rendered");
    assert
      .dom(link)
      .hasNoAttribute(
        "aria-label",
        "the verbose sentence does not override the accessible name"
      );
    assert
      .dom(link)
      .hasAttribute("title", i18n("topic.unread_posts", { count: 5 }));
  });

  test("exposes the full sentence as a description for consistent announcements", async function (assert) {
    await render(
      <template><TopicPostBadges @unreadPosts={{5}} @url="/t/1/2" /></template>
    );

    assert
      .dom(".badge-notification.unread-posts")
      .hasAttribute(
        "aria-description",
        i18n("topic.unread_posts", { count: 5 }),
        "the description matches the tooltip sentence"
      );
  });
});
