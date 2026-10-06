import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import TagSettingsLocalizations from "discourse/components/tag-settings/localizations";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { NO_VALUE_OPTION } from "discourse/ui-kit/d-native-select";

module(
  "Integration | Component | TagSettings | Localizations",
  function (hooks) {
    setupRenderingTest(hooks);

    test("source language starts blank and can be selected and cleared", async function (assert) {
      this.siteSettings.available_content_localization_locales = [
        { value: "en" },
        { value: "ja" },
      ];
      this.siteSettings.available_locales = [
        { value: "en", name: "English" },
        { value: "ja", name: "Japanese" },
      ];
      const data = { locale: null, localizations: [] };

      await render(
        <template>
          <Form @data={{data}} as |form|>
            <TagSettingsLocalizations
              @form={{form}}
              @locale={{data.locale}}
              @localizations={{data.localizations}}
            />
          </Form>
        </template>
      );

      assert
        .dom(".form-kit__section-title")
        .hasText("Localizations", "translations have a section heading");
      assert.form().field("locale").hasValue(NO_VALUE_OPTION);
      await formKit().field("locale").select("ja");
      assert.form().field("locale").hasValue("ja");
      await formKit().field("locale").select(NO_VALUE_OPTION);
      assert.form().field("locale").hasValue(NO_VALUE_OPTION);
    });
  }
);
