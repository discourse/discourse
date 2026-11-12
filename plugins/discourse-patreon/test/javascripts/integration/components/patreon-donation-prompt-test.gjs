import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { removeCookie } from "discourse/lib/cookie";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  logIn,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import Patreon, {
  incrementTopicsOpened,
} from "discourse/plugins/discourse-patreon/discourse/connectors/topic-above-footer-buttons/patreon";

module("Integration | Component | Patreon donation prompt", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    removeCookie("PatreonDonationPromptClosed");
  });

  hooks.afterEach(function () {
    removeCookie("PatreonDonationPromptClosed");
  });

  test("shows the prompt until it is closed", async function (assert) {
    logIn(getOwner(this));
    updateCurrentUser({ show_donation_prompt: true });
    this.siteSettings.patreon_enabled = true;
    this.siteSettings.patreon_donation_prompt_enabled = true;
    this.siteSettings.patreon_donation_prompt_campaign_url =
      "https://patreon.com/example";
    this.siteSettings.patreon_donation_prompt_show_after_topics = 0;
    incrementTopicsOpened();

    await render(<template><Patreon /></template>);

    assert
      .dom(
        ".topic-above-footer-buttons-outlet.patreon .patreon-donation-prompt"
      )
      .exists("shows the prompt");

    await click(".patreon-donation-prompt .close");

    assert.dom(".patreon-donation-prompt").doesNotExist("hides it on close");
  });
});
