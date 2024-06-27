import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import i18n from "discourse-common/helpers/i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreasAboutContactInformation from "admin/components/admin-config-area-cards/about/contact-information";
import AdminConfigAreasAboutGeneralSettings from "admin/components/admin-config-area-cards/about/general-settings";
import AdminConfigAreasAboutYourOrganization from "admin/components/admin-config-area-cards/about/your-organization";

export default class AdminConfigAreasAbout extends Component {
  @tracked saving = false;

  get generalSettings() {
    return {
      title: this.#lookupSettingFromData("title"),
      siteDescription: this.#lookupSettingFromData("site_description"),
      extendedSiteDescription: this.#lookupSettingFromData(
        "extended_site_description"
      ),
      aboutBannerImage: this.#lookupSettingFromData("about_banner_image"),
    };
  }

  get contactInformation() {
    return {
      communityOwner: this.#lookupSettingFromData("community_owner"),
      contactEmail: this.#lookupSettingFromData("contact_email"),
      contactURL: this.#lookupSettingFromData("contact_url"),
      contactUsername: this.#lookupSettingFromData("site_contact_username"),
      contactGroupName: this.#lookupSettingFromData("site_contact_group_name"),
    };
  }

  get yourOrganization() {
    return {
      companyName: this.#lookupSettingFromData("company_name"),
      governingLaw: this.#lookupSettingFromData("governing_law"),
      cityForDisputes: this.#lookupSettingFromData("city_for_disputes"),
    };
  }

  @action
  setSavingStatus(status) {
    this.saving = status;
  }

  #lookupSettingFromData(name) {
    return this.args.data.findBy("setting", name);
  }

  <template>
    <div class="admin-config-area">
      <h2>{{i18n "admin.config_areas.about.header"}}</h2>
      <div class="admin-config-area__primary-content">
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.general_settings"
          @primaryActionLabel="admin.config_areas.about.update"
          class="admin-config-area-about__general-settings-section"
        >
          <AdminConfigAreasAboutGeneralSettings
            @generalSettings={{this.generalSettings}}
            @setGlobalSavingStatus={{this.setSavingStatus}}
            @globalSavingStatus={{this.saving}}
          />
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.contact_information"
          @primaryActionLabel="admin.config_areas.about.update"
          class="admin-config-area-about__contact-information-section"
        >
          <AdminConfigAreasAboutContactInformation
            @contactInformation={{this.contactInformation}}
            @setGlobalSavingStatus={{this.setSavingStatus}}
            @globalSavingStatus={{this.saving}}
          />
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.your_organization"
          @primaryActionLabel="admin.config_areas.about.update"
          class="admin-config-area-about__your-organization-section"
        >
          <AdminConfigAreasAboutYourOrganization
            @yourOrganization={{this.yourOrganization}}
            @setGlobalSavingStatus={{this.setSavingStatus}}
            @globalSavingStatus={{this.saving}}
          />
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
