import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LocaleList from "discourse/admin/components/site-settings/locale-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";

module("Integration | Component | SiteSettings | LocaleList", function (hooks) {
  setupRenderingTest(hooks);

  test("shows language names and reports the list with the new select controls", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    this.siteSettings.available_locales = [
      { name: "French (Français)", value: "fr" },
      { name: "German (Deutsch)", value: "de" },
    ];
    const setting = {
      setting: "content_localization_supported_locales",
      validValues: [
        { name: "fr", value: "fr" },
        { name: "de", value: "de" },
      ],
    };
    const changes = [];
    const changeValue = (value) => changes.push(value);

    await render(
      <template>
        <LocaleList
          @allowAny={{false}}
          @changeValueCallback={{changeValue}}
          @label="Supported locales"
          @setting={{setting}}
          @value="fr"
        />
      </template>
    );

    assert.dom(".d-select").hasAttribute("data-name", "French (Français)");

    await dSelect(".d-select").select("de");
    assert.deepEqual(changes, ["fr|de"], "reports the new list");
  });
});
