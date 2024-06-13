import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import i18n from "discourse-common/helpers/i18n";
import GroupChooser from "select-kit/components/group-chooser";
import UserChooser from "select-kit/components/user-chooser";

export default class AdminConfigAreasAboutContactInformation extends Component {
  @action
  save() {
    this.args.saveCallback();
    // eslint-disable-next-line no-console
    console.log("contact information");
  }

  <template>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.community_owner"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.community_owner_help"}}
      </p>
      <input type="text" />
    </div>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.contact_email"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.contact_email_help"}}
      </p>
      <input type="text" />
    </div>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.contact_url"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.contact_url_help"}}
      </p>
      <input type="text" />
    </div>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.site_contact_name"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.site_contact_name_help"}}
      </p>
      <UserChooser />
    </div>
    <div class="control-group">
      <label>
        <span>{{i18n "admin.config_areas.about.site_contact_group"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.site_contact_group_help"}}
      </p>
      <GroupChooser />
    </div>
    <DButton
      @label="admin.config_areas.about.update"
      @action={{this.save}}
      class="btn-primary"
    />
  </template>
}
