import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import DfpCategorySettingsPanel from "../../../../admin/components/dfp-category-settings-panel";

const DfpSettings = <template>
  <div class="discourse-adplugin__dfp-settings admin-detail">
    <DPageSubheader
      @descriptionLabel={{i18n "admin.adplugin.dfp_settings.description"}}
      @titleLabel={{i18n "admin.adplugin.dfp_settings.title"}}
    />

    <DfpCategorySettingsPanel />
  </div>
</template>;

export default DfpSettings;
