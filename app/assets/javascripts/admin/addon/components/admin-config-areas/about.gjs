import Component from "@glimmer/component";
import i18n from "discourse-common/helpers/i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreasAboutContactInformation from "admin/components/admin-config-area-cards/about/contact-information";
import AdminConfigAreasAboutGeneralSettings from "admin/components/admin-config-area-cards/about/general-settings";
import AdminConfigAreasAboutYourOrganization from "admin/components/admin-config-area-cards/about/your-organization";

export default class AdminConfigAreasAbout extends Component {
  saveCallback() {
    // eslint-disable-next-line no-console
    console.log("save callback");
  }

  <template>
    <div class="admin-config-area">
      <h2>{{i18n "admin.config_areas.about.header"}}</h2>
      <div class="admin-config-area__primary-content">
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.general_settings"
          @primaryActionLabel="admin.config_areas.about.update"
        >
          <AdminConfigAreasAboutGeneralSettings
            @saveCallback={{this.saveCallback}}
          />
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.contact_information"
          @primaryActionLabel="admin.config_areas.about.update"
        >
          <AdminConfigAreasAboutContactInformation
            @saveCallback={{this.saveCallback}}
          />
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.your_organization"
          @primaryActionLabel="admin.config_areas.about.update"
        >
          <AdminConfigAreasAboutYourOrganization
            @saveCallback={{this.saveCallback}}
          />
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
