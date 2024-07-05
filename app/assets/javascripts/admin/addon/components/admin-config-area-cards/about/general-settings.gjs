import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import withEventValue from "discourse/helpers/with-event-value";
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

  @action
  async save() {
    try {
      this.args.setGlobalSavingStatus(true);
      await ajax("/admin/config/about.json", {
        type: "PUT",
        data: {
          general_settings: {
            name: this.name,
            summary: this.summary,
            extended_description: this.extendedDescription,
            about_banner_image: this.aboutBannerImage,
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

  <template>
    <div class="control-group community-name-input">
      <label>{{i18n "admin.config_areas.about.community_name"}}</label>
      <input
        {{on "input" (withEventValue (fn (mut this.name)))}}
        type="text"
        value={{this.name}}
      />
    </div>
    <div class="control-group community-summary-input">
      <label>{{i18n "admin.config_areas.about.community_summary"}}</label>
      <input
        {{on "input" (withEventValue (fn (mut this.summary)))}}
        type="text"
        value={{this.summary}}
      />
    </div>
    <div class="control-group community-description-input">
      <label>
        <span>{{i18n "admin.config_areas.about.community_description"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <DEditor @value={{this.extendedDescription}} />
    </div>
    <div class="control-group banner-image-uploader">
      <label>
        <span>{{i18n "admin.config_areas.about.banner_image"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.banner_image_help"}}
      </p>
      <UppyImageUploader
        @type="site_setting"
        @imageUrl={{this.aboutBannerImage}}
      />
    </div>
    <DButton
      @label="admin.config_areas.about.update"
      @action={{this.save}}
      @disabled={{@globalSavingStatus}}
      class="btn-primary admin-config-area-card__btn-save"
    />
  </template>
}
