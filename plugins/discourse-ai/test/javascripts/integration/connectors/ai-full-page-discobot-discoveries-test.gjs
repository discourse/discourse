import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiFullPageDiscobotDiscoveries from "discourse/plugins/discourse-ai/discourse/connectors/full-page-search-below-search-header/ai-full-page-discobot-discoveries";

module(
  "Integration | Connector | AiFullPageDiscobotDiscoveries",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.ai_discover_enabled = true;
      this.siteSettings.ai_discover_agent = "-34";
      this.currentUser.can_use_ai_discover_agent = true;
      this.currentUser.user_option.ai_search_discoveries = true;
      this.outletArgs = { search: "miyazaki" };

      this.owner.register(
        "service:ai-credits",
        class extends Service {
          async isFeatureCreditAvailable() {
            return true;
          }
        }
      );
    });

    test("does not run Discoveries when the user selected Search", async function (assert) {
      this.owner.register(
        "service:discobot-discoveries",
        class extends Service {
          mode = "search";
          showDiscoveryTitle = false;

          triggerDiscovery() {
            assert.step("trigger discovery");
          }

          onDiscoveryUpdate() {}
        }
      );

      await render(
        <template>
          <AiFullPageDiscobotDiscoveries @outletArgs={{this.outletArgs}} />
        </template>
      );

      assert.dom(".full-page-discoveries").doesNotExist();
      assert.verifySteps([]);
    });
  }
);
