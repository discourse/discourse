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
      this.loadingLocalizations = false;
      return;
    }

    this.loadingLocalizations = true;

    try {
      const response = await ajax("/admin/config/about/localizations.json", {
        data: { locale },
      });

      if (this.selectedLocale === locale) {
        this.localizations = response.localizations;
      }
    } catch (err) {
      popupAjaxError(err);
    } finally {
      if (this.selectedLocale === locale) {
        this.loadingLocalizations = false;
      }
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
      @collapseActionsOnMobile={{false}}
      @descriptionLabel={{i18n
        "admin.config.about.header_description"
        (hash basePath=(dBasePath))
      }}
      @hideTabs={{true}}
      @learnMoreUrl="https://meta.discourse.org/t/understanding-and-customizing-the-about-page/332161"
      @titleLabel={{i18n "admin.config.about.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.about.title"}}
          @path="/admin/config/about"
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      <div class="admin-config-area">
        <div class="admin-config-area__primary-content">
          {{#if this.contentLocalizationEnabled}}
            <div class="admin-config-area-about__language-toolbar">
              <Form
                class="admin-config-area-about__locale-form"
                @data={{this.localeSelectorData}}
                @onSet={{this.updateLocaleField}}
                as |form|
              >
                <form.Field
                  class="admin-config-area-about__locale-selector"
                  @format="large"
                  @helpText={{this.localeSelectorHelpText}}
                  @name="locale"
                  @showOptional={{false}}
                  @title={{i18n
                    "admin.config_areas.about.locale_selector.title"
                  }}
                  @type="select"
                  as |field|
                >
                  <field.Control
                    class="admin-config-area-about__locale-selector-dropdown"
                    @includeNone={{false}}
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
              class="admin-config-area-about__general-settings-section"
              @collapsable={{true}}
              @heading="admin.config_areas.about.general_settings"
            >
              <:content>
                <AdminConfigAreasAboutGeneralSettings
                  @generalSettings={{this.generalSettings}}
                  @globalSavingStatus={{this.saving}}
                  @isDefaultLocale={{this.isDefaultLocale}}
                  @locale={{this.selectedLocale}}
                  @localizations={{this.localizations}}
                  @setGlobalSavingStatus={{this.setSavingStatus}}
                />
              </:content>
            </AdminConfigAreaCard>
            {{#if this.isDefaultLocale}}
              <AdminConfigAreaCard
                class="admin-config-area-about__contact-information-section"
                @collapsable={{true}}
                @heading="admin.config_areas.about.contact_information"
              >
                <:content>
                  <AdminConfigAreasAboutContactInformation
                    @contactInformation={{this.contactInformation}}
                    @globalSavingStatus={{this.saving}}
                    @isDefaultLocale={{this.isDefaultLocale}}
                    @locale={{this.selectedLocale}}
                    @localizations={{this.localizations}}
                    @setGlobalSavingStatus={{this.setSavingStatus}}
                  />
                </:content>
              </AdminConfigAreaCard>
              <AdminConfigAreaCard
                class="admin-config-area-about__your-organization-section"
                @collapsable={{true}}
                @description="admin.config_areas.about.your_organization_description"
                @heading="admin.config_areas.about.your_organization"
              >
                <:content>
                  <AdminConfigAreasAboutYourOrganization
                    @globalSavingStatus={{this.saving}}
                    @isDefaultLocale={{this.isDefaultLocale}}
                    @locale={{this.selectedLocale}}
                    @localizations={{this.localizations}}
                    @setGlobalSavingStatus={{this.setSavingStatus}}
                    @yourOrganization={{this.yourOrganization}}
                  />
                </:content>
              </AdminConfigAreaCard>
              <AdminConfigAreaCard
                class="admin-config-area-about__extra-groups-section"
                @collapsable={{true}}
                @description="admin.config_areas.about.extra_groups.description"
                @heading="admin.config_areas.about.extra_groups.heading"
              >
                <:content>
                  <AdminConfigAreasAboutExtraGroups
                    @extraGroups={{this.extraGroups}}
                    @globalSavingStatus={{this.saving}}
                    @setGlobalSavingStatus={{this.setSavingStatus}}
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
