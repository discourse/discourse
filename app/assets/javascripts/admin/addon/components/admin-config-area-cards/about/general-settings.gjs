import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";

export default class AdminConfigAreasAboutGeneralSettings extends Component {
  @tracked showSavedAlert = false;

  name = this.args.generalSettings.title.value;
  summary = this.args.generalSettings.siteDescription.value;
  extendedDescription = this.args.generalSettings.extendedSiteDescription.value;
  aboutBannerImage = this.args.generalSettings.aboutBannerImage.value;

  @action
  async save() {
    this.showSavedAlert = false;
    try {
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
      this.showSavedAlert = true;
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @action
  onNameChange(event) {
    this.name = event.target.value;
  }

  @action
  onSummaryChange(event) {
    this.summary = event.target.value;
  }

  <template>
    <div class="control-group community-name-input">
      <label>{{i18n "admin.config_areas.about.community_name"}}</label>
      <input {{on "input" this.onNameChange}} type="text" value={{this.name}} />
    </div>
    <div class="control-group community-summary-input">
      <label>{{i18n "admin.config_areas.about.community_summary"}}</label>
      <input
        {{on "input" this.onSummaryChange}}
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
      class="btn-primary save-card"
    />
    {{#if this.showSavedAlert}}
      <span class="successful-save-alert">{{i18n
          "admin.config_areas.about.saved"
        }}</span>
    {{/if}}
  </template>
}
