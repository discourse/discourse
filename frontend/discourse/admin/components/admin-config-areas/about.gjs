import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import AdminConfigAreasAboutContactInformation from "discourse/admin/components/admin-config-area-cards/about/contact-information";
import AdminConfigAreasAboutExtraGroups from "discourse/admin/components/admin-config-area-cards/about/extra-groups";
import AdminConfigAreasAboutGeneralSettings from "discourse/admin/components/admin-config-area-cards/about/general-settings";
import AdminConfigAreasAboutYourOrganization from "discourse/admin/components/admin-config-area-cards/about/your-organization";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageHeader from "discourse/ui-kit/d-page-header";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasAbout extends Component {
  @service siteSettings;

  @tracked saving = false;
  @tracked loadingLocalizations = false;
  @tracked selectedLocale = this.siteSettings.default_locale;
  @tracked localizations = {};

  get isDefaultLocale() {
    return this.selectedLocale === this.siteSettings.default_locale;
  }

  get contentLocalizationEnabled() {
    return this.siteSettings.content_localization_enabled;
  }

  get localeSelectorData() {
    return { locale: this.selectedLocale };
  }

  get localeSelectorHelpText() {
    if (this.isDefaultLocale) {
      return;
    }

    return i18n("admin.config_areas.about.locale_selector.description");
  }

  get availableLocales() {
    const supportedLocales = new Set([
      this.siteSettings.default_locale,
      ...(this.siteSettings.content_localization_supported_locales || "")
        .split("|")
        .filter(Boolean),
    ]);

    return this.siteSettings.available_locales.filter((locale) =>
      supportedLocales.has(locale.value)
    );
  }

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
      companyURL: this.#lookupSettingFromData("company_url"),
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

  @action
  async updateLocale(locale) {
    this.selectedLocale = locale;

    if (this.isDefaultLocale) {
      this.localizations = {};
      return;
    }

    this.loadingLocalizations = true;

    try {
      const response = await ajax("/admin/config/about/localizations.json", {
        data: { locale },
      });
      this.localizations = response.localizations;
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.loadingLocalizations = false;
    }
  }

  @action
  async updateLocaleField(name, locale) {
    if (name === "locale") {
      await this.updateLocale(locale);
    }
  }

  #lookupSettingFromData(name) {
    return this.args.data.find((value) => value.setting === name);
  }

  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.about.title"}}
      @descriptionLabel={{i18n
        "admin.config.about.header_description"
        (hash basePath=(dBasePath))
      }}
      @hideTabs={{true}}
      @collapseActionsOnMobile={{false}}
      @learnMoreUrl="https://meta.discourse.org/t/understanding-and-customizing-the-about-page/332161"
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/about"
          @label={{i18n "admin.config.about.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <div class="admin-config-area">
        <div class="admin-config-area__primary-content">
          {{#if this.contentLocalizationEnabled}}
            <div class="admin-config-area-about__language-toolbar">
              <Form
                @data={{this.localeSelectorData}}
                @onSet={{this.updateLocaleField}}
                class="admin-config-area-about__locale-form"
                as |form|
              >
                <form.Field
                  @name="locale"
                  @title={{i18n
                    "admin.config_areas.about.locale_selector.title"
                  }}
                  @helpText={{this.localeSelectorHelpText}}
                  @format="large"
                  @showOptional={{false}}
                  @type="select"
                  class="admin-config-area-about__locale-selector"
                  as |field|
                >
                  <field.Control
                    @includeNone={{false}}
                    class="admin-config-area-about__locale-selector-dropdown"
                    as |select|
                  >
                    {{#each this.availableLocales as |locale|}}
                      <select.Option @value={{locale.value}}>
                        {{locale.name}}
                      </select.Option>
                    {{/each}}
                  </field.Control>
                </form.Field>
              </Form>
            </div>
          {{/if}}

          <DConditionalLoadingSpinner @condition={{this.loadingLocalizations}}>
            <AdminConfigAreaCard
              @heading="admin.config_areas.about.general_settings"
              @collapsable={{true}}
              class="admin-config-area-about__general-settings-section"
            >
              <:content>
                <AdminConfigAreasAboutGeneralSettings
                  @generalSettings={{this.generalSettings}}
                  @localizations={{this.localizations}}
                  @locale={{this.selectedLocale}}
                  @isDefaultLocale={{this.isDefaultLocale}}
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
                  @localizations={{this.localizations}}
                  @locale={{this.selectedLocale}}
                  @isDefaultLocale={{this.isDefaultLocale}}
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
                  @localizations={{this.localizations}}
                  @locale={{this.selectedLocale}}
                  @isDefaultLocale={{this.isDefaultLocale}}
                  @setGlobalSavingStatus={{this.setSavingStatus}}
                  @globalSavingStatus={{this.saving}}
                />
              </:content>
            </AdminConfigAreaCard>
            {{#if this.isDefaultLocale}}
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
            {{/if}}
          </DConditionalLoadingSpinner>
        </div>
      </div>
    </div>
  </template>
}
