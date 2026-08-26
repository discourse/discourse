import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiFullPageDiscobotDiscoveries from "discourse/plugins/discourse-ai/discourse/connectors/full-page-search-below-search-header/ai-full-page-discobot-discoveries";

module(
  "Integration | Connector | AiFullPageDiscobotDiscoveries",
  function (hooks) {
    setupRenderingTest(hooks);

    // Rendering the connector directly would bypass `shouldRender`, which the
    // outlet is what consults — and it is the whole point here: declining to
    // render is what keeps the component from being constructed, so neither its
    // credit check nor its discovery request is ever sent.
    test("stays out of full-page search entirely", function (assert) {
      this.siteSettings.ai_discover_enabled = true;
      this.siteSettings.ai_discover_agent = "-34";
      this.currentUser.can_use_ai_discover_agent = true;
      this.currentUser.user_option.ai_search_discoveries = true;

      assert.false(
        AiFullPageDiscobotDiscoveries.shouldRender(
          {},
          {
            siteSettings: this.siteSettings,
            currentUser: this.currentUser,
          }
        ),
        "even with the feature fully enabled for the user"
      );
    });
  }
);
