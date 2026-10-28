import Component from "@glimmer/component";
import { computed } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class DfpAdCategorySettings extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.discourse_adplugin_enabled;
  }

  @service site;

  // classic @computed so a MessageBus `Site.currentProp` update invalidates it
  @computed("site.dfp_category_settings", "args.outletArgs.category.id")
  get hasDashboardConfiguration() {
    const categoryId = this.args.outletArgs.category?.id;
    const dashboardSettings = this.site.get("dfp_category_settings")?.[
      String(categoryId)
    ];

    return Boolean(
      dashboardSettings?.gam_adunit || dashboardSettings?.gam_keywords
    );
  }

  <template>
    <@outletArgs.form.Section
      class="category-custom-settings-outlet dfp-ad-category-settings"
      @subtitle={{i18n "adplugin.gam_category_settings.legacy_description"}}
      @title={{i18n "adplugin.gam_category_settings.title"}}
    >
      {{#if this.hasDashboardConfiguration}}
        <p class="alert alert-info">
          {{i18n "adplugin.gam_category_settings.dashboard_override"}}
          <LinkTo @route="adminPlugins.show.dfpSettings">
            {{i18n "adplugin.gam_category_settings.dashboard_link"}}
          </LinkTo>
        </p>
      {{/if}}

      <@outletArgs.form.Object @name="custom_fields" as |object|>
        <object.Field
          @format="max"
          @name="gam_adunit"
          @title={{i18n "adplugin.gam_adunit"}}
          @type="input"
          as |field|
        >
          <field.Control
            placeholder={{i18n "adplugin.gam_adunit_placeholder"}}
          />
        </object.Field>

        <object.Field
          @format="max"
          @name="gam_keywords"
          @title={{i18n "adplugin.gam_keywords"}}
          @type="input"
          as |field|
        >
          <field.Control
            placeholder={{i18n "adplugin.gam_keywords_placeholder"}}
          />
        </object.Field>

        <object.Field
          @format="max"
          @name="gtm_taxonomy"
          @title={{i18n "adplugin.gtm_taxonomy"}}
          @type="input"
          as |field|
        >
          <field.Control
            placeholder={{i18n "adplugin.gtm_taxonomy_placeholder"}}
          />
        </object.Field>
      </@outletArgs.form.Object>
    </@outletArgs.form.Section>
  </template>
}
