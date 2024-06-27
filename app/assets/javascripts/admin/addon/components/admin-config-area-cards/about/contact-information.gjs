import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import UserChooser from "select-kit/components/user-chooser";

export default class AdminConfigAreasAboutContactInformation extends Component {
  @service site;
  @service toasts;

  @tracked
  contactUsername = this.args.contactInformation.contactUsername.value || null;
  @tracked
  contactGroupId = this.site.groups.find(
    (group) => group.name === this.contactGroupName
  )?.id;

  communityOwner = this.args.contactInformation.communityOwner.value;
  contactEmail = this.args.contactInformation.contactEmail.value;
  contactURL = this.args.contactInformation.contactURL.value;
  contactGroupName = this.args.contactInformation.contactGroupName.value;

  @action
  onContactUsernameChange(usernames) {
    this.contactUsername = usernames[0];
  }

  @action
  onContactGroupIdChange(ids, groups) {
    this.contactGroupId = ids[0];
    this.contactGroupName = groups[0]?.name;
  }

  @action
  async save() {
    try {
      this.args.setGlobalSavingStatus(true);
      await ajax("/admin/config/about.json", {
        type: "PUT",
        data: {
          contact_information: {
            community_owner: this.communityOwner,
            contact_email: this.contactEmail,
            contact_url: this.contactURL,
            contact_username: this.contactUsername,
            contact_group_name: this.contactGroupName,
          },
        },
      });
      this.toasts.success({
        duration: 3000,
        data: {
          message: I18n.t(
            "admin.config_areas.about.toasts.contact_information_saved"
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
    <div class="control-group community-owner-input">
      <label>
        <span>{{i18n "admin.config_areas.about.community_owner"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.community_owner_help"}}
      </p>
      <input
        {{on "input" (withEventValue (fn (mut this.communityOwner)))}}
        type="text"
        value={{this.communityOwner}}
      />
    </div>
    <div class="control-group contact-email-input">
      <label>
        <span>{{i18n "admin.config_areas.about.contact_email"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.contact_email_help"}}
      </p>
      <input
        {{on "input" (withEventValue (fn (mut this.contactEmail)))}}
        type="text"
        value={{this.contactEmail}}
      />
    </div>
    <div class="control-group contact-url-input">
      <label>
        <span>{{i18n "admin.config_areas.about.contact_url"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.contact_url_help"}}
      </p>
      <input
        {{on "input" (withEventValue (fn (mut this.contactURL)))}}
        type="text"
        value={{this.contactURL}}
      />
    </div>
    <div class="control-group site-contact-username-input">
      <label>
        <span>{{i18n "admin.config_areas.about.site_contact_name"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.site_contact_name_help"}}
      </p>
      <UserChooser
        @value={{this.contactUsername}}
        @onChange={{this.onContactUsernameChange}}
        @options={{hash maximum=1}}
      />
    </div>
    <div class="control-group site-contact-group-input">
      <label>
        <span>{{i18n "admin.config_areas.about.site_contact_group"}}</span>
        <span class="admin-config-area-card__label-optional">{{i18n
            "admin.config_areas.about.optional"
          }}</span>
      </label>
      <p class="admin-config-area-card__additional-help">
        {{i18n "admin.config_areas.about.site_contact_group_help"}}
      </p>
      <GroupChooser
        @content={{this.site.groups}}
        @value={{this.contactGroupId}}
        @onChange={{this.onContactGroupIdChange}}
        @options={{hash maximum=1}}
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
