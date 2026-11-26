import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingComponent from "discourse/admin/components/site-setting";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | enabled reactions site setting",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the like reaction is listed first and cannot be removed", async function (assert) {
      this.siteSettings.discourse_reactions_reaction_for_like = "heart";
      const setting = SiteSetting.create({
        setting: "discourse_reactions_enabled_reactions",
        value: "laughing",
        type: "emoji_list",
      });

      await render(
        <template><SiteSettingComponent @setting={{setting}} /></template>
      );

      assert
        .dom(".form-kit__field .value[data-index='0'] .emoji-name")
        .hasText("heart", "the like reaction is prepended");
      assert
        .dom(".form-kit__field .value[data-index='0'] .remove-value-btn")
        .isDisabled();
      assert
        .dom(".form-kit__field .value[data-index='1'] .remove-value-btn")
        .isEnabled();
    });
  }
);
