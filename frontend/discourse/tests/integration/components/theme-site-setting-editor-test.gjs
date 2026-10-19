import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import ThemeSiteSettingEditor from "discourse/admin/components/theme-site-setting-editor";
import SiteSetting from "discourse/admin/models/site-setting";
import Theme from "discourse/admin/models/theme";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | ThemeSiteSettingEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("shows link to the staff action logs for the setting on hover", async function (assert) {
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
          @model={{this.model}}
          @setting={{this.setting}}
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

  test("an enum setting buffers the picked value", async function (assert) {
    const setting = SiteSetting.create({
      setting: "tag_style",
      value: "simple",
      default: "simple",
      type: "enum",
      valid_values: [
        { name: "Simple", value: "simple" },
        { name: "Box", value: "box" },
      ],
    });
    const model = Theme.create({ name: "Test Theme" });

    await render(
      <template>
        <ThemeSiteSettingEditor @model={{model}} @setting={{setting}} />
      </template>
    );

    await selectKit().expand();
    await selectKit().selectRowByValue("box");

    assert.strictEqual(
      setting.buffered.get("value"),
      "box",
      "writes the picked value to the setting's buffer"
    );
    assert.strictEqual(
      selectKit().header().value(),
      "box",
      "shows the buffered value"
    );
  });
});
