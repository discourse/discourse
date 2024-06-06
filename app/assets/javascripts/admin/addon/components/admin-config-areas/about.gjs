import Component from "@glimmer/component";
import i18n from "discourse-common/helpers/i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreasAboutContactInformation from "admin/components/admin-config-area-cards/about/contact-information";
import AdminConfigAreasAboutGeneralSettings from "admin/components/admin-config-area-cards/about/general-settings";
import AdminConfigAreasAboutYourOrganization from "admin/components/admin-config-area-cards/about/your-organization";

export default class AdminConfigAreasAbout extends Component {
  get generalSettings() {
    const hash = {};

    hash.title = this.#lookupSettingFromData("title");
    hash.siteDescription = this.#lookupSettingFromData("site_description");
    hash.extendedSiteDescription = this.#lookupSettingFromData(
      "extended_site_description"
    );
    hash.aboutBannerImage = this.#lookupSettingFromData("about_banner_image");

    return hash;
  }

  get contactInformation() {
    const hash = {};

    hash.communityOwner = this.#lookupSettingFromData("community_owner");
    hash.contactEmail = this.#lookupSettingFromData("contact_email");
    hash.contactURL = this.#lookupSettingFromData("contact_url");
    hash.contactUsername = this.#lookupSettingFromData("site_contact_username");
    hash.contactGroupName = this.#lookupSettingFromData(
      "site_contact_group_name"
    );

    return hash;
  }

  get yourOrganization() {
    const hash = {};

    hash.companyName = this.#lookupSettingFromData("company_name");
    hash.governingLaw = this.#lookupSettingFromData("governing_law");
    hash.cityForDisputes = this.#lookupSettingFromData("city_for_disputes");

    return hash;
  }

  saveCallback() {}

  #lookupSettingFromData(name) {
    for (const setting of this.args.data) {
      if (setting.setting === name) {
        return setting;
      }
    }
  }

  <template>
    <div class="admin-config-area">
      <h2>{{i18n "admin.config_areas.about.header"}}</h2>
      <div class="admin-config-area__primary-content">
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.general_settings"
          @primaryActionLabel="admin.config_areas.about.update"
          class="general-settings-section"
        >
          <AdminConfigAreasAboutGeneralSettings
            @generalSettings={{this.generalSettings}}
            @saveCallback={{this.saveCallback}}
          />
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.contact_information"
          @primaryActionLabel="admin.config_areas.about.update"
          class="contact-information-section"
        >
          <AdminConfigAreasAboutContactInformation
            @contactInformation={{this.contactInformation}}
            @saveCallback={{this.saveCallback}}
          />
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.your_organization"
          @primaryActionLabel="admin.config_areas.about.update"
          class="your-organization-section"
        >
          <AdminConfigAreasAboutYourOrganization
            @yourOrganization={{this.yourOrganization}}
            @saveCallback={{this.saveCallback}}
          />
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
