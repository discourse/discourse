import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import {
  discourseModule,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const buildTopic = function (opts) {
  return Topic.create({
    id: 4563,
  }).updateFromJson({
    title: "Qunit Test Topic",
    details: {
      notification_level: opts.level,
      notifications_reason_id: opts.reason || null,
    },
    archetype: opts.archetype || "regular",
    category_id: opts.category_id || null,
    tags: opts.tags || [],
  });
};

const originalTranslation =
  I18n.translations.en.js.topic.notifications.tracking_pm.title;

discourseModule(
  "Integration | Component | select-kit/topic-notifications-button",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      I18n.translations.en.js.topic.notifications.tracking_pm.title = originalTranslation;
    });

    componentTest("the header has a localized title", {
      template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.set("topic", buildTopic({ level: 1 }));
      },

      async test(assert) {
        assert.equal(
          selectKit().header().label(),
          "Normal",
          "it has the correct label"
        );

        await this.set("topic", buildTopic({ level: 2 }));

        assert.equal(
          selectKit().header().label(),
          "Tracking",
          "it correctly changes the label"
        );
      },
    });

    componentTest("the header has a localized title", {
      template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        I18n.translations.en.js.topic.notifications.tracking_pm.title = `${originalTranslation} PM`;
        this.set(
          "topic",
          buildTopic({ level: 2, archetype: "private_message" })
        );
      },

      test(assert) {
        assert.equal(
          selectKit().header().label(),
          `${originalTranslation} PM`,
          "it has the correct label for PMs"
        );
      },
    });

    componentTest("notification reason text - user mailing list mode", {
      template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.currentUser.set("mailing_list_mode", true);
        this.set("topic", buildTopic({ level: 2 }));
      },

      test(assert) {
        assert.equal(
          queryAll(".topic-notifications-button .text").text(),
          I18n.t("topic.notifications.reasons.mailing_list_mode"),
          "mailing_list_mode enabled for the user shows unique text"
        );
      },
    });

    componentTest("notification reason text - bad notification reason", {
      template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.set("topic", buildTopic({ level: 2 }));
      },

      test(assert) {
        this.set("topic", buildTopic({ level: 3, reason: 999 }));

        assert.equal(
          queryAll(".topic-notifications-button .text").text(),
          I18n.t("topic.notifications.reasons.3"),
          "fallback to regular level translation if reason does not exist"
        );
      },
    });

    componentTest("notification reason text - user tracking category", {
      template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.currentUser.set("tracked_category_ids", [88]);
        this.set("topic", buildTopic({ level: 2, reason: 8, category_id: 88 }));
      },

      test(assert) {
        assert.equal(
          queryAll(".topic-notifications-button .text").text(),
          I18n.t("topic.notifications.reasons.2_8"),
          "use 2_8 notification if user is still tracking category"
        );
      },
    });

    componentTest(
      "notification reason text - user no longer tracking category",
      {
        template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

        beforeEach() {
          this.currentUser.set("tracked_category_ids", []);
          this.set(
            "topic",
            buildTopic({ level: 2, reason: 8, category_id: 88 })
          );
        },

        test(assert) {
          assert.equal(
            queryAll(".topic-notifications-button .text").text(),
            I18n.t("topic.notifications.reasons.2_8_stale"),
            "use _stale notification if user is no longer tracking category"
          );
        },
      }
    );

    componentTest("notification reason text - user watching category", {
      template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.currentUser.set("watched_category_ids", [88]);
        this.set("topic", buildTopic({ level: 3, reason: 6, category_id: 88 }));
      },

      test(assert) {
        assert.equal(
          queryAll(".topic-notifications-button .text").text(),
          I18n.t("topic.notifications.reasons.3_6"),
          "use 3_6 notification if user is still watching category"
        );
      },
    });

    componentTest(
      "notification reason text - user no longer watching category",
      {
        template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

        beforeEach() {
          this.currentUser.set("watched_category_ids", []);
          this.set(
            "topic",
            buildTopic({ level: 3, reason: 6, category_id: 88 })
          );
        },

        test(assert) {
          assert.equal(
            queryAll(".topic-notifications-button .text").text(),
            I18n.t("topic.notifications.reasons.3_6_stale"),
            "use _stale notification if user is no longer watching category"
          );
        },
      }
    );

    componentTest("notification reason text - user watching tag", {
      template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.currentUser.set("watched_tags", ["test"]);
        this.set("topic", buildTopic({ level: 3, reason: 10, tags: ["test"] }));
      },

      test(assert) {
        assert.equal(
          queryAll(".topic-notifications-button .text").text(),
          I18n.t("topic.notifications.reasons.3_10"),
          "use 3_10 notification if user is still watching tag"
        );
      },
    });

    componentTest("notification reason text - user no longer watching tag", {
      template: hbs`
        {{topic-notifications-button
          notificationLevel=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.currentUser.set("watched_tags", []);
        this.set("topic", buildTopic({ level: 3, reason: 10, tags: ["test"] }));
      },

      test(assert) {
        assert.equal(
          queryAll(".topic-notifications-button .text").text(),
          I18n.t("topic.notifications.reasons.3_10_stale"),
          "use _stale notification if user is no longer watching tag"
        );
      },
    });
  }
);
