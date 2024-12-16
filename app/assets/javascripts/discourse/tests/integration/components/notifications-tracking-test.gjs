import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicNotificationsTracking from "discourse/components/topic-notifications-tracking";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

function extractDescriptions(rows) {
  return [...rows].map((el) =>
    el
      .querySelector(".notifications-tracking-btn__description")
      .textContent.trim()
  );
}

function getTranslations(type = "") {
  return ["watching", "tracking", "regular", "muted"].map((key) => {
    return i18n(`topic.notifications.${key}${type}.description`);
  });
}

module("Integration | Component | TopicTracking", function (hooks) {
  setupRenderingTest(hooks);

  test("regular topic notification level descriptions", async function (assert) {
    await render(<template>
      <TopicNotificationsTracking @levelId={{1}} />
    </template>);

    await click(".notifications-tracking-trigger");

    const uiTexts = extractDescriptions(
      document.querySelectorAll(".notifications-tracking-btn")
    );
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
    await render(<template>
      <TopicNotificationsTracking @levelId={{1}} />
    </template>);

    await click(".notifications-tracking-trigger");

    const uiTexts = extractDescriptions(
      document.querySelectorAll(".notifications-tracking-btn")
    );
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
});
