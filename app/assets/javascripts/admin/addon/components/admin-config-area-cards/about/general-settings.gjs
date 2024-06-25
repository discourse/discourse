import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DEditor from "discourse/components/d-editor";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import i18n from "discourse-common/helpers/i18n";

export default class AdminConfigAreasAboutGeneralSettings extends Component {
  @action
  save() {
    this.args.saveCallback();
    // eslint-disable-next-line no-console
    console.log("general settings");
  }

  <template>
    <div class="control-group">
      <label>{{i18n "admin.config_areas.about.community_name"}}</label>
      <input type="text" />
    </div>
    <div class="control-group">
      <label>{{i18n "admin.config_areas.about.community_summary"}}</label>
      <input type="text" />
    </div>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.community_description"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <DEditor />
    </div>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.banner_image"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.banner_image_help"}}
      </p>
      <UppyImageUploader />
    </div>
    <DButton
      @label="admin.config_areas.about.update"
      @action={{this.save}}
      class="btn-primary"
    />
  </template>
}
