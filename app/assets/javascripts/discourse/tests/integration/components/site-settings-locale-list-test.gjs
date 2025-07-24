import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import SiteSettingComponent from "admin/components/site-setting";
import SiteSetting from "admin/models/site-setting";

module("Integration | Component | locale-list site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    const self = this;

    this.siteSettings.available_locales = [
      { value: "en", name: "English" },
      { value: "ja", name: "Japanese" },
      { value: "fr", name: "French" },
    ];

    this.set(
      "setting",
      SiteSetting.create({
        category: "foo",
        default: "",
        description: "Choose locales",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "content_localization_supported_locales",
        type: "locale_list",
        valid_values: [
          { value: "en", name: "English" },
          { value: "ja", name: "Japanese" },
          { value: "fr", name: "French" },
        ],
        value: "en,ja",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    assert.strictEqual(
      subject.header().value(),
      "en,ja",
      "it selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("fr");

    assert.strictEqual(
      subject.header().value(),
      "en,ja,fr",
      "it allows to select a locale from the list of choices"
    );
  });

  test("changing locale list", async function (assert) {
    const self = this;

    this.siteSettings.available_locales = [
      { value: "en", name: "English" },
      { value: "ja", name: "Japanese" },
      { value: "fr", name: "French" },
    ];

    this.set(
      "setting",
      SiteSetting.create({
        category: "foo",
        default: "",
        description: "Choose locales",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "content_localization_supported_locales",
        type: "locale_list",
        valid_values: [
          { value: "en", name: "English" },
          { value: "ja", name: "Japanese" },
          { value: "fr", name: "French" },
        ],
        value: "en,ja",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    const subject = selectKit(".list-setting");

    assert.strictEqual(
      subject.header().value(),
      "en,ja",
      "it initially selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("ja");

    assert.strictEqual(
      subject.header().value(),
      "en,ja,ja",
      "it allows to add a locale to the selected values"
    );
  });
});
