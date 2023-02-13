import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import I18n from "I18n";
import { query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { getOwner } from "discourse-common/lib/get-owner";

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

    test("the header has a localized title", async function (assert) {
      this.set("topic", buildTopic.call(this, { level: 1 }));

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        selectKit().header().label(),
        "Normal",
        "it has the correct label"
      );

      this.set("topic", buildTopic.call(this, { level: 2 }));

      assert.strictEqual(
        selectKit().header().label(),
        "Tracking",
        "it correctly changes the label"
      );
    });

    test("the header has a localized title", async function (assert) {
      I18n.translations.en.js.topic.notifications.tracking_pm.title = `${originalTranslation} PM`;
      this.set(
        "topic",
        buildTopic.call(this, { level: 2, archetype: "private_message" })
      );

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        selectKit().header().label(),
        `${originalTranslation} PM`,
        "it has the correct label for PMs"
      );
    });

    test("notification reason text - user mailing list mode", async function (assert) {
      this.currentUser.set("user_option.mailing_list_mode", true);
      this.set("topic", buildTopic.call(this, { level: 2 }));

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        query(".topic-notifications-button .text").innerText,
        I18n.t("topic.notifications.reasons.mailing_list_mode"),
        "mailing_list_mode enabled for the user shows unique text"
      );
    });

    test("notification reason text - bad notification reason", async function (assert) {
      this.set("topic", buildTopic.call(this, { level: 2 }));

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      this.set("topic", buildTopic.call(this, { level: 3, reason: 999 }));

      assert.strictEqual(
        query(".topic-notifications-button .text").innerText,
        I18n.t("topic.notifications.reasons.3"),
        "fallback to regular level translation if reason does not exist"
      );
    });

    test("notification reason text - user tracking category", async function (assert) {
      this.currentUser.set("tracked_category_ids", [88]);
      this.set(
        "topic",
        buildTopic.call(this, { level: 2, reason: 8, category_id: 88 })
      );

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        query(".topic-notifications-button .text").innerText,
        I18n.t("topic.notifications.reasons.2_8"),
        "use 2_8 notification if user is still tracking category"
      );
    });

    test("notification reason text - user no longer tracking category", async function (assert) {
      this.currentUser.set("tracked_category_ids", []);
      this.set(
        "topic",
        buildTopic.call(this, { level: 2, reason: 8, category_id: 88 })
      );

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        query(".topic-notifications-button .text").innerText,
        I18n.t("topic.notifications.reasons.2_8_stale"),
        "use _stale notification if user is no longer tracking category"
      );
    });

    test("notification reason text - user watching category", async function (assert) {
      this.currentUser.set("watched_category_ids", [88]);
      this.set(
        "topic",
        buildTopic.call(this, { level: 3, reason: 6, category_id: 88 })
      );

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        query(".topic-notifications-button .text").innerText,
        I18n.t("topic.notifications.reasons.3_6"),
        "use 3_6 notification if user is still watching category"
      );
    });

    test("notification reason text - user no longer watching category", async function (assert) {
      this.currentUser.set("watched_category_ids", []);
      this.set(
        "topic",
        buildTopic.call(this, { level: 3, reason: 6, category_id: 88 })
      );

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        query(".topic-notifications-button .text").innerText,
        I18n.t("topic.notifications.reasons.3_6_stale"),
        "use _stale notification if user is no longer watching category"
      );
    });

    test("notification reason text - user watching tag", async function (assert) {
      this.currentUser.set("watched_tags", ["test"]);
      this.set(
        "topic",
        buildTopic.call(this, { level: 3, reason: 10, tags: ["test"] })
      );

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        query(".topic-notifications-button .text").innerText,
        I18n.t("topic.notifications.reasons.3_10"),
        "use 3_10 notification if user is still watching tag"
      );
    });

    test("notification reason text - user no longer watching tag", async function (assert) {
      this.currentUser.set("watched_tags", []);
      this.set(
        "topic",
        buildTopic.call(this, { level: 3, reason: 10, tags: ["test"] })
      );

      await render(hbs`
        <TopicNotificationsButton
          @notificationLevel={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      assert.strictEqual(
        query(".topic-notifications-button .text").innerText,
        I18n.t("topic.notifications.reasons.3_10_stale"),
        "use _stale notification if user is no longer watching tag"
      );
    });
  }
);
