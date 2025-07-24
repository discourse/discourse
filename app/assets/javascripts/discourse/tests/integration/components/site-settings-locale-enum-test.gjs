import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import SiteSettingComponent from "admin/components/site-setting";
import SiteSetting from "admin/models/site-setting";

module("Integration | Component | locale-enum site-setting", function (hooks) {
  setupRenderingTest(hooks);

  test("default", async function (assert) {
    const self = this;

    this.set("languageNameLookup", {
      getLanguageName(value) {
        return { en: "English", ja: "Japanese", fr: "French" }[value];
      },
    });

    this.owner.register(
      "service:language-name-lookup",
      this.languageNameLookup,
      { instantiate: false }
    );

    this.set(
      "setting",
      SiteSetting.create({
        category: "required",
        default: "ja",
        description: "Choose a locale",
        placeholder: null,
        preview: null,
        setting: "default_locale",
        type: "locale_enum",
        valid_values: [{ value: "en" }, { value: "ja" }, { value: "fr" }],
        value: "en",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    await pauseTest();
    const subject = selectKit("select-kit");

    assert.strictEqual(
      subject.header().value(),
      "en",
      "it selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("ja");

    assert.strictEqual(
      subject.header().value(),
      "ja",
      "it allows to select a locale from the dropdown"
    );
  });

  test("changing locale enum value", async function (assert) {
    const self = this;

    this.set("languageNameLookup", {
      getLanguageName(value) {
        return { en: "English", ja: "Japanese", fr: "French" }[value];
      },
    });

    this.owner.register(
      "service:language-name-lookup",
      this.languageNameLookup,
      { instantiate: false }
    );

    this.set(
      "setting",
      SiteSetting.create({
        category: "foo",
        default: "en",
        description: "Choose a locale",
        placeholder: null,
        preview: null,
        secret: false,
        setting: "default_locale",
        type: "locale",
        valid_values: [{ value: "en" }, { value: "ja" }, { value: "fr" }],
        value: "en",
      })
    );

    await render(
      <template><SiteSettingComponent @setting={{self.setting}} /></template>
    );

    const subject = selectKit("select-kit");

    assert.strictEqual(
      subject.header().value(),
      "en",
      "it initially selects the setting's value"
    );

    await subject.expand();
    await subject.selectRowByValue("fr");

    assert.strictEqual(
      subject.header().value(),
      "fr",
      "it allows to change the selected locale"
    );
  });
});
