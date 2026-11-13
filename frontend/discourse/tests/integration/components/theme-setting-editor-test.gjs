import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ThemeSettingEditor from "discourse/admin/components/theme-setting-editor";
import ThemeSettings from "discourse/admin/models/theme-settings";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | ThemeSettingEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("renders an anchor for a theme setting", async function (assert) {
    const setting = ThemeSettings.create({
      setting: "show_description",
      humanized_name: "Show description",
      type: "bool",
      value: true,
      default: true,
    });

    await render(
      <template>
        <ThemeSettingEditor @model={{hash id=1}} @setting={{setting}} />
      </template>
    );

    assert.dom(".setting").hasAttribute("id", "setting-show_description");
    assert
      .dom(".setting-link")
      .hasAttribute("href", "#setting-show_description")
      .hasAttribute(
        "aria-label",
        i18n("admin.customize.theme.setting_link_label", {
          name: "Show description",
        })
      );
    assert.dom(".setting").hasClass("linkable");
    assert.dom(".setting-label__heading > h3 + .setting-link").exists();
    assert.dom(".setting-label h3 .setting-link").doesNotExist();
    assert.dom(".setting-label h3").doesNotIncludeText(
      i18n("admin.customize.theme.setting_link_label", {
        name: "Show description",
      })
    );
    assert.dom(".setting-label h3").doesNotHaveAttribute("tabindex");
  });
});
