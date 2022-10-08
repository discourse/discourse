import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import I18n from "I18n";
import Topic from "discourse/models/topic";
import { hbs } from "ember-cli-htmlbars";
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

function extractDescriptions(rows) {
  return [...rows].map((el) => el.querySelector(".desc").textContent.trim());
}

function getTranslations(type = "") {
  return ["watching", "tracking", "regular", "muted"].map((key) => {
    return I18n.t(`topic.notifications.${key}${type}.description`);
  });
}

module(
  "Integration | Component | select-kit/topic-notifications-options",
  function (hooks) {
    setupRenderingTest(hooks);

    test("regular topic notification level descriptions", async function (assert) {
      this.set("topic", buildTopic("regular"));

      await render(hbs`
        <TopicNotificationsOptions
          @value={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      await selectKit().expand();

      const uiTexts = extractDescriptions(selectKit().rows());
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
    });

    test("PM topic notification level descriptions", async function (assert) {
      this.set("topic", buildTopic("private_message"));

      await render(hbs`
        <TopicNotificationsOptions
          @value={{this.topic.details.notification_level}}
          @topic={{this.topic}}
        />
      `);

      await selectKit().expand();

      const uiTexts = extractDescriptions(selectKit().rows());
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
    });
  }
);
