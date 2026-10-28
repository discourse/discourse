import BackButton from "discourse/components/back-button";
import DfpCategorySettingForm from "discourse/plugins/discourse-adplugin/admin/components/dfp-category-setting-form";

export default <template>
  <BackButton
    @label="admin.adplugin.dfp_settings.back"
    @route="adminPlugins.show.dfpSettings.index"
  />

  <DfpCategorySettingForm @model={{@model}} />
</template>
