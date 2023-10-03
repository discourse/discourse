import { visit } from "@ember/test-helpers";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("User Tips - first_notification", function (needs) {
  needs.user({ new_personal_messages_notifications_count: 1 });
  needs.site({ user_tips: { first_notification: 1 } });

  test("Shows first notification user tip", async function (assert) {
    this.siteSettings.enable_user_tips = true;

    await visit("/t/internationalization-localization/280");
    assert.equal(
      query(".user-tip__title").textContent.trim(),
      I18n.t("user_tips.first_notification.title")
    );
  });
});

acceptance("User Tips - topic_timeline", function (needs) {
  needs.user();
  needs.site({ user_tips: { topic_timeline: 2 } });

  test("Shows topic timeline user tip", async function (assert) {
    this.siteSettings.enable_user_tips = true;

    await visit("/t/internationalization-localization/280");
    assert.equal(
      query(".user-tip__title").textContent.trim(),
      I18n.t("user_tips.topic_timeline.title")
    );
  });
});

acceptance("User Tips - post_menu", function (needs) {
  needs.user();
  needs.site({ user_tips: { post_menu: 3 } });

  test("Shows post menu user tip", async function (assert) {
    this.siteSettings.enable_user_tips = true;

    await visit("/t/internationalization-localization/280");
    assert.equal(
      query(".user-tip__title").textContent.trim(),
      I18n.t("user_tips.post_menu.title")
    );
  });
});

acceptance("User Tips - topic_notification_levels", function (needs) {
  needs.user();
  needs.site({ user_tips: { topic_notification_levels: 4 } });

  test("Shows topic notification levels user tip", async function (assert) {
    this.siteSettings.enable_user_tips = true;

    await visit("/t/internationalization-localization/280");

    assert.equal(
      query(".user-tip__title").textContent.trim(),
      I18n.t("user_tips.topic_notification_levels.title")
    );
  });
});

acceptance("User Tips - suggested_topics", function (needs) {
  needs.user();
  needs.site({ user_tips: { suggested_topics: 5 } });

  test("Shows suggested topics user tip", async function (assert) {
    this.siteSettings.enable_user_tips = true;

    await visit("/t/internationalization-localization/280");
    assert.equal(
      query(".user-tip__title").textContent.trim(),
      I18n.t("user_tips.suggested_topics.title")
    );
  });
});
