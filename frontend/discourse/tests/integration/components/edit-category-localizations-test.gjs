import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import EditCategoryLocalizations from "discourse/admin/components/edit-category-localizations";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { NO_VALUE_OPTION } from "discourse/ui-kit/d-native-select";

module("Integration | Component | EditCategoryLocalizations", function (hooks) {
  setupRenderingTest(hooks);

  test("source language can be cleared", async function (assert) {
    this.siteSettings.available_content_localization_locales = [
      { value: "en" },
    ];
    this.siteSettings.available_locales = [
      { value: "en", name: "English" },
      { value: "ja", name: "Japanese" },
    ];
    const data = { locale: "en", localizations: [] };

    await render(
      <template>
        <Form @data={{data}} as |form|>
          <EditCategoryLocalizations
            @form={{form}}
            @selectedTab="localizations"
            @transientData={{data}}
          />
        </Form>
      </template>
    );

    assert
      .dom(".edit-category-tab-localizations")
      .hasClass("form-kit__section", "the panel uses FormKit section spacing");
    await formKit().field("locale").select(NO_VALUE_OPTION);
    assert.form().field("locale").hasValue(NO_VALUE_OPTION);
  });
});
