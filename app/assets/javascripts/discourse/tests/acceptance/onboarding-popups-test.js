import { visit } from "@ember/test-helpers";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("Onboarding Popup - topic_notification_levels", function (needs) {
  needs.site({ onboarding_popup_types: { topic_notification_levels: 1 } });
  needs.user({ auto_track_topics_after_msecs: 60000 });

  test("Shows post menu onboarding popup", async function (assert) {
    this.siteSettings.enable_onboarding_popups = true;

    await visit("/t/internationalization-localization/280");

    assert.equal(
      query(".onboarding-popup-title").textContent.trim(),
      I18n.t("popup.topic_notification_levels.title")
    );
  });
});

acceptance("Onboarding Popup - topic_menu", function (needs) {
  needs.site({ onboarding_popup_types: { topic_menu: 1 } });
  needs.user();

  test("Shows post menu onboarding popup", async function (assert) {
    this.siteSettings.enable_onboarding_popups = true;

    await visit("/t/internationalization-localization/280");
    assert.equal(
      query(".onboarding-popup-title").textContent.trim(),
      I18n.t("popup.topic_menu.title")
    );
  });
});

acceptance("Onboarding Popup - suggested_topics", function (needs) {
  needs.site({ onboarding_popup_types: { suggested_topics: 1 } });
  needs.user();

  test("Shows post menu onboarding popup", async function (assert) {
    this.siteSettings.enable_onboarding_popups = true;

    await visit("/t/internationalization-localization/280");
    assert.equal(
      query(".onboarding-popup-title").textContent.trim(),
      I18n.t("popup.suggested_topics.title")
    );
  });
});
