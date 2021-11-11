import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const buildTopic = function (archetype) {
  return Topic.create({
    id: 4563,
  }).updateFromJson({
    title: "Qunit Test Topic",
    details: {
      notification_level: 1,
    },
    archetype,
  });
};

function extractDescs(rows) {
  return Array.from(
    rows.find(".desc").map(function () {
      return this.textContent.trim();
    })
  );
}

function getTranslations(type = "") {
  return ["watching", "tracking", "regular", "muted"].map((key) => {
    return I18n.t(`topic.notifications.${key}${type}.description`);
  });
}

discourseModule(
  "Integration | Component | select-kit/topic-notifications-options",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("regular topic notification level descriptions", {
      template: hbs`
        {{topic-notifications-options
          value=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.set("topic", buildTopic("regular"));
      },

      async test(assert) {
        await selectKit().expand();

        const uiTexts = extractDescs(selectKit().rows());
        const descriptions = getTranslations();

        assert.strictEqual(
          uiTexts.length,
          descriptions.length,
          "it has the correct copy"
        );
        uiTexts.forEach((text, index) => {
          assert.strictEqual(
            text.trim(),
            descriptions[index].trim(),
            "it has the correct copy"
          );
        });
      },
    });

    componentTest("PM topic notification level descriptions", {
      template: hbs`
        {{topic-notifications-options
          value=topic.details.notification_level
          topic=topic
        }}
      `,

      beforeEach() {
        this.set("topic", buildTopic("private_message"));
      },

      async test(assert) {
        await selectKit().expand();

        const uiTexts = extractDescs(selectKit().rows());
        const descriptions = getTranslations("_pm");

        assert.strictEqual(
          uiTexts.length,
          descriptions.length,
          "it has the correct copy"
        );

        uiTexts.forEach((text, index) => {
          assert.strictEqual(
            text.trim(),
            descriptions[index].trim(),
            "it has the correct copy"
          );
        });
      },
    });
  }
);
