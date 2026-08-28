import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiFullPageDiscobotDiscoveries from "discourse/plugins/discourse-ai/discourse/connectors/full-page-search-below-search-header/ai-full-page-discobot-discoveries";

module(
  "Integration | Connector | AiFullPageDiscobotDiscoveries",
  function (hooks) {
    setupRenderingTest(hooks);

    // `shouldRender` is what the outlet consults, and declining there is what
    // keeps the component from being constructed at all — so neither its credit
    // check nor a discovery request is sent for a user who cannot ask.
    test("renders for a user who can ask", function (assert) {
      this.siteSettings.ai_ask_ai_enabled = true;
      this.siteSettings.ai_ask_ai_agent = "-41";
      this.currentUser.can_use_ask_ai = true;

      assert.true(
        AiFullPageDiscobotDiscoveries.shouldRender(
          {},
          { siteSettings: this.siteSettings, currentUser: this.currentUser }
        ),
        "asking is offered on full-page search"
      );

      this.currentUser.user_option.ai_search_discoveries = false;

      assert.true(
        AiFullPageDiscobotDiscoveries.shouldRender(
          {},
          { siteSettings: this.siteSettings, currentUser: this.currentUser }
        ),
        "the deprecated Discoveries preference does not disable Ask AI"
      );
    });
  }
);
