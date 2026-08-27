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
      this.siteSettings.ai_discover_enabled = true;
      this.siteSettings.ai_discover_agent = "-34";
      this.currentUser.can_use_ai_discover_agent = true;
      this.currentUser.user_option.ai_search_discoveries = true;

      assert.true(
        AiFullPageDiscobotDiscoveries.shouldRender(
          {},
          { siteSettings: this.siteSettings, currentUser: this.currentUser }
        ),
        "asking is offered on full-page search"
      );

      this.currentUser.user_option.ai_search_discoveries = false;

      assert.false(
        AiFullPageDiscobotDiscoveries.shouldRender(
          {},
          { siteSettings: this.siteSettings, currentUser: this.currentUser }
        ),
        "and stays out entirely for a user who turned it off"
      );
    });
  }
);
