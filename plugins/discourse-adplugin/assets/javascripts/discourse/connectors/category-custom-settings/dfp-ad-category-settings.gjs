import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class DfpAdCategorySettings extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.discourse_adplugin_enabled;
  }

  <template>
    <@outletArgs.form.Section
      class="category-custom-settings-outlet dfp-ad-category-settings"
      @title={{i18n "adplugin.gam_category_settings.title"}}
    >
      <@outletArgs.form.Object @name="custom_fields" as |object|>
        <object.Field
          @format="max"
          @name="gam_adunit"
          @title={{i18n "adplugin.gam_category_settings.gam_adunit"}}
          @type="input"
          as |field|
        >
          <field.Control
            placeholder={{i18n
              "adplugin.gam_category_settings.gam_adunit_placeholder"
            }}
          />
        </object.Field>

        <object.Field
          @format="max"
          @name="gam_keywords"
          @title={{i18n "adplugin.gam_category_settings.gam_keywords"}}
          @type="input"
          as |field|
        >
          <field.Control
            placeholder={{i18n
              "adplugin.gam_category_settings.gam_keywords_placeholder"
            }}
          />
        </object.Field>

        <object.Field
          @format="max"
          @name="gtm_taxonomy"
          @title={{i18n "adplugin.gam_category_settings.gtm_taxonomy"}}
          @type="input"
          as |field|
        >
          <field.Control
            placeholder={{i18n
              "adplugin.gam_category_settings.gtm_taxonomy_placeholder"
            }}
          />
        </object.Field>
      </@outletArgs.form.Object>
    </@outletArgs.form.Section>
  </template>
}
