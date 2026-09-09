import EmberObject from "@ember/object";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import BrowseMore from "discourse/components/more-topics/browse-more";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | MoreTopics | BrowseMore", function (hooks) {
  setupRenderingTest(hooks);

  test("updates counts when the topic tracking state changes", async function (assert) {
    this.currentUser.unified_new_enabled = true;
    this.siteSettings.enable_unified_new = true;

    const topicTrackingState = this.owner.lookup(
      "service:topic-tracking-state"
    );
    topicTrackingState.loadStates([
      {
        topic_id: 123,
        last_read_post_number: 1,
        highest_post_number: 2,
        notification_level: NotificationLevels.TRACKING,
      },
    ]);

    const topic = EmberObject.create({
      category: null,
      isPrivateMessage: false,
    });

    await render(<template><BrowseMore @topic={{topic}} /></template>);

    assert
      .dom(".more-topics__browse-more a[href='/new?subset=replies']")
      .hasText("1 unread", "the unread count is rendered");

    topicTrackingState.updateSeen(123, 2);
    await settled();

    assert
      .dom(".more-topics__browse-more a[href='/new?subset=replies']")
      .doesNotExist("the unread count is removed after reading the topic");
  });
});
