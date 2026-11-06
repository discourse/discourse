import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import DfpCategorySettingsPanel from "discourse/plugins/discourse-adplugin/admin/components/dfp-category-settings-panel";

export default <template>
  <DPageSubheader
    @descriptionLabel={{i18n "admin.adplugin.dfp_settings.description"}}
    @titleLabel={{i18n "admin.adplugin.dfp_settings.title"}}
  >
    <:actions as |actions|>
      <actions.Primary
        @icon="plus"
        @label="admin.adplugin.dfp_settings.add"
        @route="adminPlugins.show.dfpSettings.new"
      />
    </:actions>
  </DPageSubheader>

  <DfpCategorySettingsPanel @settings={{@model.settings}} />
</template>
