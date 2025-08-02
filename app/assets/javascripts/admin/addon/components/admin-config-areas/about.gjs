import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import AdminConfigAreasAboutContactInformation from "admin/components/admin-config-area-cards/about/contact-information";
import AdminConfigAreasAboutExtraGroups from "admin/components/admin-config-area-cards/about/extra-groups";
import AdminConfigAreasAboutGeneralSettings from "admin/components/admin-config-area-cards/about/general-settings";
import AdminConfigAreasAboutYourOrganization from "admin/components/admin-config-area-cards/about/your-organization";

export default class AdminConfigAreasAbout extends Component {
  @service siteSettings;

  @tracked saving = false;

  get generalSettings() {
    return {
      title: this.#lookupSettingFromData("title"),
      siteDescription: this.#lookupSettingFromData("site_description"),
      extendedSiteDescription: this.#lookupSettingFromData(
        "extended_site_description"
      ),
      communityTitle: this.#lookupSettingFromData("short_site_description"),
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

  get extraGroups() {
    return {
      aboutPageExtraGroups: this.#lookupSettingFromData(
        "about_page_extra_groups"
      ),
      aboutPageExtraGroupsInitialMembers: this.#lookupSettingFromData(
        "about_page_extra_groups_initial_members"
      ),
      aboutPageExtraGroupsOrder: this.#lookupSettingFromData(
        "about_page_extra_groups_order"
      ),
      aboutPageExtraGroupsShowDescription: this.#lookupSettingFromData(
        "about_page_extra_groups_show_description"
      ),
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
      <div class="admin-config-area__primary-content">
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.general_settings"
          @collapsable={{true}}
          class="admin-config-area-about__general-settings-section"
        >
          <:content>
            <AdminConfigAreasAboutGeneralSettings
              @generalSettings={{this.generalSettings}}
              @setGlobalSavingStatus={{this.setSavingStatus}}
              @globalSavingStatus={{this.saving}}
            />
          </:content>
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.contact_information"
          @collapsable={{true}}
          class="admin-config-area-about__contact-information-section"
        >
          <:content>
            <AdminConfigAreasAboutContactInformation
              @contactInformation={{this.contactInformation}}
              @setGlobalSavingStatus={{this.setSavingStatus}}
              @globalSavingStatus={{this.saving}}
            />
          </:content>
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.your_organization"
          @description="admin.config_areas.about.your_organization_description"
          @collapsable={{true}}
          class="admin-config-area-about__your-organization-section"
        >
          <:content>
            <AdminConfigAreasAboutYourOrganization
              @yourOrganization={{this.yourOrganization}}
              @setGlobalSavingStatus={{this.setSavingStatus}}
              @globalSavingStatus={{this.saving}}
            />
          </:content>
        </AdminConfigAreaCard>
        <AdminConfigAreaCard
          @heading="admin.config_areas.about.extra_groups.heading"
          @description="admin.config_areas.about.extra_groups.description"
          @collapsable={{true}}
          class="admin-config-area-about__extra-groups-section"
        >
          <:content>
            <AdminConfigAreasAboutExtraGroups
              @extraGroups={{this.extraGroups}}
              @setGlobalSavingStatus={{this.setSavingStatus}}
              @globalSavingStatus={{this.saving}}
            />
          </:content>
        </AdminConfigAreaCard>
      </div>
    </div>
  </template>
}
