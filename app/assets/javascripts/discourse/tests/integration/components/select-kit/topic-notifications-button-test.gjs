import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import I18n, { i18n } from "discourse-i18n";
import TopicNotificationsButton from "select-kit/components/topic-notifications-button";

class TestClass {
  @tracked topic;
}

function buildTopic(opts) {
  return this.store.createRecord("topic", {
    id: 4563,
    title: "Qunit Test Topic",
    details: {
      notification_level: opts.level,
      notifications_reason_id: opts.reason || null,
    },
    archetype: opts.archetype || "regular",
    category_id: opts.category_id || null,
    tags: opts.tags || [],
  });
}

const originalTranslation =
  I18n.translations.en.js.topic.notifications.tracking_pm.title;

module(
  "Integration | Component | select-kit/topic-notifications-button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.store = getOwner(this).lookup("service:store");
    });

    hooks.afterEach(function () {
      I18n.translations.en.js.topic.notifications.tracking_pm.title =
        originalTranslation;
    });

    test("the header has correct labels", async function (assert) {
      const state = new TestClass();
      state.topic = buildTopic.call(this, { level: 1 });

      await render(<template>
        <TopicNotificationsButton @topic={{state.topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".notifications-tracking-trigger")
        .hasText("Normal", "has the correct label");

      state.topic = buildTopic.call(this, { level: 2 });
      await settled();

      assert
        .dom(".notifications-tracking-trigger")
        .hasText("Tracking", "has the correct label");
    });

    test("the header has a localized title", async function (assert) {
      I18n.translations.en.js.topic.notifications.tracking_pm.title = `${originalTranslation} PM`;
      const topic = buildTopic.call(this, {
        level: 2,
        archetype: "private_message",
      });

      await render(<template>
        <TopicNotificationsButton @topic={{topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".notifications-tracking-trigger")
        .hasText(`${originalTranslation} PM`, "has the correct label for PMs");
    });

    test("notification reason text - user mailing list mode", async function (assert) {
      this.currentUser.set("user_option.mailing_list_mode", true);
      const topic = buildTopic.call(this, { level: 2 });

      await render(<template>
        <TopicNotificationsButton @topic={{topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".topic-notifications-button .text")
        .hasText(
          i18n("topic.notifications.reasons.mailing_list_mode"),
          "mailing_list_mode enabled for the user shows unique text"
        );
    });

    test("notification reason text - bad notification reason", async function (assert) {
      const state = new TestClass();
      state.topic = buildTopic.call(this, { level: 2 });

      await render(<template>
        <TopicNotificationsButton @topic={{state.topic}} @expanded={{true}} />
      </template>);

      state.topic = buildTopic.call(this, { level: 3, reason: 999 });
      await settled();

      assert
        .dom(".topic-notifications-button .text")
        .hasText(
          i18n("topic.notifications.reasons.3"),
          "fallback to regular level translation if reason does not exist"
        );
    });

    test("notification reason text - user tracking category", async function (assert) {
      this.currentUser.set("tracked_category_ids", [88]);
      const topic = buildTopic.call(this, {
        level: 2,
        reason: 8,
        category_id: 88,
      });

      await render(<template>
        <TopicNotificationsButton @topic={{topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".topic-notifications-button .text")
        .hasText(
          i18n("topic.notifications.reasons.2_8"),
          "use 2_8 notification if user is still tracking category"
        );
    });

    test("notification reason text - user no longer tracking category", async function (assert) {
      this.currentUser.set("tracked_category_ids", []);
      const topic = buildTopic.call(this, {
        level: 2,
        reason: 8,
        category_id: 88,
      });

      await render(<template>
        <TopicNotificationsButton @topic={{topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".topic-notifications-button .text")
        .hasText(
          i18n("topic.notifications.reasons.2_8_stale"),
          "use _stale notification if user is no longer tracking category"
        );
    });

    test("notification reason text - user watching category", async function (assert) {
      this.currentUser.set("watched_category_ids", [88]);
      const topic = buildTopic.call(this, {
        level: 3,
        reason: 6,
        category_id: 88,
      });

      await render(<template>
        <TopicNotificationsButton @topic={{topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".topic-notifications-button .text")
        .hasText(
          i18n("topic.notifications.reasons.3_6"),
          "use 3_6 notification if user is still watching category"
        );
    });

    test("notification reason text - user no longer watching category", async function (assert) {
      this.currentUser.set("watched_category_ids", []);
      const topic = buildTopic.call(this, {
        level: 3,
        reason: 6,
        category_id: 88,
      });

      await render(<template>
        <TopicNotificationsButton @topic={{topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".topic-notifications-button .text")
        .hasText(
          i18n("topic.notifications.reasons.3_6_stale"),
          "use _stale notification if user is no longer watching category"
        );
    });

    test("notification reason text - user watching tag", async function (assert) {
      this.currentUser.set("watched_tags", ["test"]);
      const topic = buildTopic.call(this, {
        level: 3,
        reason: 10,
        tags: ["test"],
      });

      await render(<template>
        <TopicNotificationsButton @topic={{topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".topic-notifications-button .text")
        .hasText(
          i18n("topic.notifications.reasons.3_10"),
          "use 3_10 notification if user is still watching tag"
        );
    });

    test("notification reason text - user no longer watching tag", async function (assert) {
      this.currentUser.set("watched_tags", []);
      const topic = buildTopic.call(this, {
        level: 3,
        reason: 10,
        tags: ["test"],
      });

      await render(<template>
        <TopicNotificationsButton @topic={{topic}} @expanded={{true}} />
      </template>);

      assert
        .dom(".topic-notifications-button .text")
        .hasText(
          i18n("topic.notifications.reasons.3_10_stale"),
          "use _stale notification if user is no longer watching tag"
        );
    });
  }
);
