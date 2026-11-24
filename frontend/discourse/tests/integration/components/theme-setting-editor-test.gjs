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

  test("falls back to the setting key when it has no display name", async function (assert) {
    const setting = ThemeSettings.create({
      setting: "cards",
      type: "bool",
      value: true,
      default: true,
    });

    await render(
      <template>
        <ThemeSettingEditor @model={{hash id=1}} @setting={{setting}} />
      </template>
    );

    assert.dom(".setting-label h3").includesText("cards");
    assert
      .dom(".setting-link")
      .hasAttribute(
        "aria-label",
        i18n("admin.customize.theme.setting_link_label", { name: "cards" })
      );
  });

  test("a color list setting edits its colors in a color list with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    const setting = ThemeSettings.create({
      setting: "brand_colors",
      humanized_name: "Brand colors",
      type: "list",
      list_type: "color",
      value: "FF0000|00FF00",
      default: "",
    });

    await render(
      <template>
        <ThemeSettingEditor @model={{hash id=1}} @setting={{setting}} />
      </template>
    );

    assert.deepEqual(
      [
        ...document.querySelectorAll(".color-list__row .d-color-input__hex"),
      ].map((input) => input.value),
      ["ff0000", "00ff00"]
    );
    assert.dom(".select-string-list").doesNotExist();
  });
});
