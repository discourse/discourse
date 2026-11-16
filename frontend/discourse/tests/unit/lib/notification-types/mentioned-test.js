import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import Notification from "discourse/models/notification";
import { NOTIFICATION_TYPES } from "discourse/tests/fixtures/concerns/notification-types";
import { createRenderDirector } from "discourse/tests/helpers/notification-types-helper";

module("Unit | Notification Types | mentioned", function (hooks) {
  setupTest(hooks);

  test("reviewable mentions retain the regular mention appearance", function (assert) {
    const notification = Notification.create({
      notification_type: NOTIFICATION_TYPES.mentioned,
      topic_id: null,
      post_number: null,
      data: {
        reviewable_id: 123,
        reviewable_note_id: 456,
        topic_title: "Review <script>alert('title')</script>",
        display_username: "moderator",
      },
    });
    const director = createRenderDirector(
      notification,
      "mentioned",
      this.owner.lookup("service:site-settings")
    );

    assert.strictEqual(
      director.linkHref,
      "/review/123",
      "the mention links to its reviewable"
    );
    assert.strictEqual(
      director.description,
      notification.data.topic_title,
      "the reviewable title is plain text for escaped rendering"
    );
    assert.strictEqual(director.label, "moderator", "the author is the label");
    assert.strictEqual(
      director.icon,
      "notification.mentioned",
      "the regular mention icon is retained"
    );

    setPrefix("/forum");

    assert.strictEqual(
      director.linkHref,
      "/forum/review/123",
      "the link respects the site base path"
    );
  });

  test("topic mentions continue to link to their post", function (assert) {
    const notification = Notification.create({
      notification_type: NOTIFICATION_TYPES.mentioned,
      topic_id: 100,
      post_number: 5,
      slug: "test-topic",
      fancy_title: "Test &lt;topic&gt;",
      data: { topic_title: "Test <topic>", display_username: "author" },
    });
    const director = createRenderDirector(
      notification,
      "mentioned",
      this.owner.lookup("service:site-settings")
    );

    assert.strictEqual(
      director.linkHref,
      "/t/test-topic/100/5",
      "the mention links to the original post"
    );
    assert.strictEqual(
      director.description.toString(),
      notification.fancy_title,
      "the topic's formatted title is retained"
    );
  });
});
