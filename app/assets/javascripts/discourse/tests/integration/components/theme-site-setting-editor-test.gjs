import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ThemeSiteSettingEditor from "admin/components/theme-site-setting-editor";
import SiteSetting from "admin/models/site-setting";
import Theme from "admin/models/theme";

module("Integration | Component | ThemeSiteSettingEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("shows link to the staff action logs for the setting on hover", async function (assert) {
    const self = this;

    this.set(
      "setting",
      SiteSetting.create({
        setting: "enable_welcome_banner",
        value: "false",
        default: "true",
        type: "bool",
      })
    );

    this.set("model", Theme.create({ name: "Test Theme" }));

    await render(
      <template>
        <ThemeSiteSettingEditor
          @setting={{self.setting}}
          @model={{self.model}}
        />
      </template>
    );

    await triggerEvent("[data-setting='enable_welcome_banner']", "mouseenter");

    assert
      .dom("[data-setting='enable_welcome_banner'] .staff-action-log-link")
      .exists()
      .hasAttribute(
        "href",
        `/admin/logs/staff_action_logs?filters=${encodeURIComponent(JSON.stringify({ subject: "Test Theme: enable_welcome_banner", action_name: "change_theme_site_setting" }))}&force_refresh=true`
      );
  });
});
