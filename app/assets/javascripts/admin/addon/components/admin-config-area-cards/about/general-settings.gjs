import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";

export default class AdminConfigAreasAboutGeneralSettings extends Component {
  @service toasts;

  name = this.args.generalSettings.title.value;
  summary = this.args.generalSettings.siteDescription.value;
  extendedDescription = this.args.generalSettings.extendedSiteDescription.value;
  aboutBannerImage = this.args.generalSettings.aboutBannerImage.value;

  @cached
  get data() {
    return {
      name: this.args.generalSettings.title.value,
      summary: this.args.generalSettings.siteDescription.value,
      extendedDescription:
        this.args.generalSettings.extendedSiteDescription.value,
      communityTitle: this.args.generalSettings.communityTitle.value,
      aboutBannerImage: this.args.generalSettings.aboutBannerImage.value,
    };
  }

  @action
  async save(data) {
    try {
      this.args.setGlobalSavingStatus(true);
      await ajax("/admin/config/about.json", {
        type: "PUT",
        data: {
          general_settings: {
            name: data.name,
            summary: data.summary,
            extended_description: data.extendedDescription,
            community_title: data.communityTitle,
            about_banner_image: data.aboutBannerImage,
          },
        },
      });
      this.toasts.success({
        duration: 3000,
        data: {
          message: I18n.t(
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
        as |field|
      >
        <field.Input
          placeholder={{i18n
            "admin.config_areas.about.community_name_placeholder"
          }}
        />
      </form.Field>

      <form.Field
        @name="summary"
        @title={{i18n "admin.config_areas.about.community_summary"}}
        @format="large"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="extendedDescription"
        @title={{i18n "admin.config_areas.about.community_description"}}
        as |field|
      >
        <field.Composer />
      </form.Field>

      <form.Field
        @name="communityTitle"
        @title={{i18n "admin.config_areas.about.community_title"}}
        @description={{i18n "admin.config_areas.about.community_title_help"}}
        @format="large"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Field
        @name="aboutBannerImage"
        @title={{i18n "admin.config_areas.about.banner_image"}}
        @description={{i18n "admin.config_areas.about.banner_image_help"}}
        @onSet={{this.setImage}}
        as |field|
      >
        <field.Image @type="site_setting" />
      </form.Field>

      <form.Submit
        @label="admin.config_areas.about.update"
        @disabled={{@globalSavingStatus}}
      />
    </Form>
  </template>
}
