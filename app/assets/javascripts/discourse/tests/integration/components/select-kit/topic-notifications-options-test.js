import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import I18n from "I18n";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { getOwner } from "discourse-common/lib/get-owner";

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
      const store = getOwner(this).lookup("service:store");
      this.set(
        "topic",
        store.createRecord("topic", {
          id: 4563,
          title: "Qunit Test Topic",
          archetype: "regular",
          details: {
            notification_level: 1,
          },
        })
      );

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
      const store = getOwner(this).lookup("service:store");
      this.set(
        "topic",
        store.createRecord("topic", {
          id: 4563,
          title: "Qunit Test Topic",
          archetype: "private_message",
          details: {
            notification_level: 1,
          },
        })
      );

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
