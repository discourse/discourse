import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";
import TopicNotificationsOptions from "select-kit/components/topic-notifications-options";

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
      const topic = store.createRecord("topic", {
        id: 4563,
        title: "Qunit Test Topic",
        archetype: "regular",
        details: {
          notification_level: 1,
        },
      });

      await render(<template>
        <TopicNotificationsOptions
          @value={{topic.details.notification_level}}
          @topic={{topic}}
        />
      </template>);

      await selectKit().expand();

      const uiTexts = extractDescriptions(selectKit().rows());
      const descriptions = getTranslations();

      assert.strictEqual(
        uiTexts.length,
        descriptions.length,
        "has the correct copy"
      );

      uiTexts.forEach((text, index) => {
        assert.strictEqual(
          text.trim(),
          descriptions[index].trim(),
          "has the correct copy"
        );
      });
    });

    test("PM topic notification level descriptions", async function (assert) {
      const store = getOwner(this).lookup("service:store");
      const topic = store.createRecord("topic", {
        id: 4563,
        title: "Qunit Test Topic",
        archetype: "private_message",
        details: {
          notification_level: 1,
        },
      });

      await render(<template>
        <TopicNotificationsOptions
          @value={{topic.details.notification_level}}
          @topic={{topic}}
        />
      </template>);

      await selectKit().expand();

      const uiTexts = extractDescriptions(selectKit().rows());
      const descriptions = getTranslations("_pm");

      assert.strictEqual(
        uiTexts.length,
        descriptions.length,
        "has the correct copy"
      );

      uiTexts.forEach((text, index) => {
        assert.strictEqual(
          text.trim(),
          descriptions[index].trim(),
          "has the correct copy"
        );
      });
    });
  }
);
