import { visit } from "@ember/test-helpers";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { test } from "qunit";

acceptance("Onboarding Popup - user_card", function (needs) {
  needs.user();
  needs.site({ onboarding_popup_types: { user_card: 1 } });

  test("Shows post menu onboarding popup", async function (assert) {
    this.siteSettings.enable_onboarding_popups = true;

    await visit("/t/internationalization-localization/280");
    assert.equal(
      query(".onboarding-popup-title").textContent.trim(),
      I18n.t("popup.user_card.title")
    );
  });
});
