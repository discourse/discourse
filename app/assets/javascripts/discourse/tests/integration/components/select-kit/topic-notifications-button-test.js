import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const buildTopic = function (level, archetype = "regular") {
  return Topic.create({
    id: 4563,
  }).updateFromJson({
    title: "Qunit Test Topic",
    details: {
      notification_level: level,
    },
    archetype,
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
        this.set("topic", buildTopic(1));
      },

      async test(assert) {
        assert.equal(
          selectKit().header().label(),
          "Normal",
          "it has the correct label"
        );

        await this.set("topic", buildTopic(2));

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
        this.set("topic", buildTopic(2, "private_message"));
      },

      test(assert) {
        assert.equal(
          selectKit().header().label(),
          `${originalTranslation} PM`,
          "it has the correct label for PMs"
        );
      },
    });
  }
);
