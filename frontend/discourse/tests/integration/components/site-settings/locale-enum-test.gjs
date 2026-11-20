import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LocaleEnum from "discourse/admin/components/site-settings/locale-enum";
import SiteSetting from "discourse/admin/models/site-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";

module("Integration | Component | SiteSettings | LocaleEnum", function (hooks) {
  setupRenderingTest(hooks);

  test("names each locale and reports the pick with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.siteSettings.available_locales = [
      { value: "en", name: "English (US)" },
      { value: "fr", name: "French (Français)" },
    ];
    const setting = SiteSetting.create({
      setting: "default_locale",
      type: "locale_enum",
      valid_values: [
        { name: "languages.en.name", value: "en" },
        { name: "languages.fr.name", value: "fr" },
      ],
    });
    const changes = [];
    const changeValue = (value) => changes.push(value);

    await render(
      <template>
        <LocaleEnum
          @changeValueCallback={{changeValue}}
          @label="Default locale"
          @setting={{setting}}
          @value="fr"
        />
      </template>
    );

    assert.dom(".d-select").hasAttribute("data-name", "French (Français)");
    assert
      .dom(".d-select input[role='combobox']")
      .hasAria("label", "Default locale");

    await dSelect(".d-select").select("en");
    assert.deepEqual(changes, ["en"]);
  });
});
