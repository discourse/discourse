import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasAboutGeneralSettings extends Component {
  @service toasts;

  @cached
  get data() {
    return {
      name: this.#settingValue("title", this.args.generalSettings.title),
      summary: this.#settingValue(
        "site_description",
        this.args.generalSettings.siteDescription
      ),
      extendedDescription: this.#settingValue(
        "extended_site_description",
        this.args.generalSettings.extendedSiteDescription
      ),
      communityTitle: this.#settingValue(
        "short_site_description",
        this.args.generalSettings.communityTitle
      ),
      aboutBannerImage: this.args.generalSettings.aboutBannerImage.value,
    };
  }

  @action
  async save(data) {
    try {
      this.args.setGlobalSavingStatus(true);
      await ajax(this.#savePath, {
        type: "PUT",
        data: this.#saveData(data),
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            "admin.config_areas.about.toasts.general_settings_saved"
          ),
        },
      });
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.args.setGlobalSavingStatus(false);
    }
  }

  get #savePath() {
    if (this.args.isDefaultLocale) {
      return "/admin/config/about.json";
    }

    return "/admin/config/about/localizations.json";
  }

  #saveData(data) {
    const payload = {
      locale: this.args.locale,
      general_settings: {
        name: data.name,
        summary: data.summary,
        extended_description: data.extendedDescription,
        community_title: data.communityTitle,
      },
    };

    if (this.args.isDefaultLocale) {
      payload.general_settings.about_banner_image = data.aboutBannerImage;
    }

    return payload;
  }

  #settingValue(settingName, setting) {
    if (this.args.isDefaultLocale) {
      return setting.value;
    }

    return this.args.localizations?.[settingName]?.value ?? setting.value;
  }

  @action
  setImage(upload, { set }) {
    set("aboutBannerImage", upload?.url);
  }

  <template>
    <Form @data={{this.data}} @onSubmit={{this.save}} as |form|>
      <form.Field
        @name="name"
        @title={{i18n "admin.config_areas.about.community_name"}}
        @validation="required"
        @format="large"
        @type="input"
        as |field|
      >
        <field.Control
          placeholder={{i18n
            "admin.config_areas.about.community_name_placeholder"
          }}
        />
      </form.Field>

      <form.Field
        @name="summary"
        @title={{i18n "admin.config_areas.about.community_summary"}}
        @format="large"
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @name="extendedDescription"
        @title={{i18n "admin.config_areas.about.community_description"}}
        @type="composer"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Field
        @name="communityTitle"
        @title={{i18n "admin.config_areas.about.community_title"}}
        @description={{i18n "admin.config_areas.about.community_title_help"}}
        @format="large"
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>

      {{#if @isDefaultLocale}}
        <form.Field
          @name="aboutBannerImage"
          @title={{i18n "admin.config_areas.about.banner_image"}}
          @helpText={{i18n "admin.config_areas.about.banner_image_help"}}
          @onSet={{this.setImage}}
          @type="image"
          as |field|
        >
          <field.Control @type="site_setting" />
        </form.Field>
      {{/if}}

      <form.Submit
        @label="admin.config_areas.about.update"
        @disabled={{@globalSavingStatus}}
      />
    </Form>
  </template>
}
