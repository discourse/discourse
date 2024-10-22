import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { NotificationLevels } from "discourse/lib/notification-levels";
import {
  nextTopicUrl,
  previousTopicUrl,
  setTopicId,
} from "discourse/lib/topic-list-tracker";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("Topic list tracking", function (needs) {
  let notificationLevel;

  needs.hooks.afterEach(() => {
    notificationLevel = null;
  });

  needs.user();

  needs.pretender((server, helper) => {
    server.get("/latest.json", () => {
      const fixture = cloneJSON(discoveryFixtures["/latest.json"]);

      if (notificationLevel) {
        fixture["topic_list"]["topics"].find((t) => {
          if (t.id === 11557) {
            t.notification_level = notificationLevel;
          }
        });
      }

      return helper.response(cloneJSON(fixture));
    });

    server.get("/t/11557.json", () => {
      const topicFixture = cloneJSON(topicFixtures["/t/130.json"]);
      topicFixture.id = 11557;
      return helper.response(topicFixture);
    });
  });

  test("Navigation", async function (assert) {
    await visit("/");
    let url = await nextTopicUrl();
    assert.strictEqual(url, "/t/error-after-upgrade-to-0-9-7-9/11557");

    setTopicId(11557);

    url = await nextTopicUrl();
    assert.strictEqual(url, "/t/welcome-to-meta-discourse-org/1");

    url = await previousTopicUrl();
    assert.strictEqual(url, "/t/error-after-upgrade-to-0-9-7-9/11557");
  });

  test("unread count is set on topic that user is tracking", async function (assert) {
    notificationLevel = NotificationLevels.TRACKING;

    await visit("/");

    await click(".raw-topic-link[data-topic-id='11557']");

    await visit("/");

    assert
      .dom("tr[data-topic-id='11557'] .unread-posts")
      .exists("unread count for topic is shown");
  });

  test("unread count is not set on topic that user is not tracking", async function (assert) {
    notificationLevel = NotificationLevels.REGULAR;

    await visit("/");

    await click(".raw-topic-link[data-topic-id='11557']");

    await visit("/");

    assert
      .dom("tr[data-topic-id='11557'] .unread-posts")
      .doesNotExist("unread count for topic is not shown");
  });
});
