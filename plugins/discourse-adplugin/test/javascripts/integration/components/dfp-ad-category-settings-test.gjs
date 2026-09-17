import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import DfpAdCategorySettings from "discourse/plugins/discourse-adplugin/discourse/connectors/category-custom-settings/dfp-ad-category-settings";

module("Integration | Component | DfpAdCategorySettings", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the GAM fields for a category", async function (assert) {
    this.data = { custom_fields: {} };
    this.category = { id: 41, slug: "cards-talk", custom_fields: {} };

    await render(
      <template>
        <Form @data={{this.data}} as |form|>
          <DfpAdCategorySettings
            @outletArgs={{hash category=this.category form=form}}
          />
        </Form>
      </template>
    );

    assert.dom(".dfp-ad-category-settings").exists("the GAM section renders");

    assert
      .dom('.dfp-ad-category-settings input[name="custom_fields.gam_adunit"]')
      .exists("the gam_adunit field renders")
      .hasAttribute(
        "placeholder",
        i18n("adplugin.gam_category_settings.gam_adunit_placeholder"),
        "the gam_adunit placeholder is shown"
      );
    assert
      .dom('.dfp-ad-category-settings input[name="custom_fields.gam_keywords"]')
      .exists("the gam_keywords field renders");
    assert
      .dom('.dfp-ad-category-settings input[name="custom_fields.gtm_taxonomy"]')
      .exists("the gtm_taxonomy field renders");
  });

  test("shows existing category custom field values", async function (assert) {
    this.data = {
      custom_fields: {
        gam_adunit: "/8438/stltoday.com/sports/forums/cards-talk",
        gam_keywords: "sports,mlb",
        gtm_taxonomy: "sports/forums/cards-talk",
      },
    };
    this.category = {
      id: 41,
      slug: "cards-talk",
      custom_fields: this.data.custom_fields,
    };

    await render(
      <template>
        <Form @data={{this.data}} as |form|>
          <DfpAdCategorySettings
            @outletArgs={{hash category=this.category form=form}}
          />
        </Form>
      </template>
    );

    assert
      .dom('.dfp-ad-category-settings input[name="custom_fields.gam_adunit"]')
      .hasValue(
        "/8438/stltoday.com/sports/forums/cards-talk",
        "the saved gam_adunit is shown"
      );
    assert
      .dom('.dfp-ad-category-settings input[name="custom_fields.gam_keywords"]')
      .hasValue("sports,mlb", "the saved gam_keywords are shown");
    assert
      .dom('.dfp-ad-category-settings input[name="custom_fields.gtm_taxonomy"]')
      .hasValue("sports/forums/cards-talk", "the saved gtm_taxonomy is shown");
  });
});
