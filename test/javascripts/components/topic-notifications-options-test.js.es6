import componentTest from "helpers/component-test";
import Topic from "discourse/models/topic";

const buildTopic = function(archetype) {
  return Topic.create({
    id: 4563,
    title: "Qunit Test Topic",
    details: {
      notification_level: 1
    },
    archetype
  });
};

function extractDescs(rows) {
  return Array.from(
    rows.find(".desc").map(function() {
      return this.textContent.trim();
    })
  );
}

function getTranslations(type = "") {
  return ["watching", "tracking", "regular", "muted"].map(key => {
    return I18n.t(`topic.notifications.${key}${type}.description`);
  });
}

moduleForComponent("topic-notifications-options", { integration: true });

componentTest("regular topic notification level descriptions", {
  template:
    "{{topic-notifications-options value=topic.details.notification_level topic=topic}}",

  async test(assert) {
    await selectKit().expand();
    await this.set("topic", buildTopic("regular"));

    const uiTexts = extractDescs(selectKit().rows());
    const descriptions = getTranslations();

    assert.equal(
      uiTexts.length,
      descriptions.length,
      "it has the correct copy"
    );
    uiTexts.forEach((text, index) => {
      assert.equal(
        text.trim(),
        descriptions[index].trim(),
        "it has the correct copy"
      );
    });
  }
});

componentTest("PM topic notification level descriptions", {
  template:
    "{{topic-notifications-options value=topic.details.notification_level topic=topic}}",

  async test(assert) {
    await selectKit().expand();
    await this.set("topic", buildTopic("private_message"));

    const uiTexts = extractDescs(selectKit().rows());
    const descriptions = getTranslations("_pm");

    assert.equal(
      uiTexts.length,
      descriptions.length,
      "it has the correct copy"
    );

    uiTexts.forEach((text, index) => {
      assert.equal(
        text.trim(),
        descriptions[index].trim(),
        "it has the correct copy"
      );
    });
  }
});
