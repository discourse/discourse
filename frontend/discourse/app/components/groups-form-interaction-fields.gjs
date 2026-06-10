/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
import { NotificationLevels } from "discourse/lib/notification-levels";
import ComboBox from "discourse/select-kit/components/combo-box";
import NotificationsButton from "discourse/select-kit/components/notifications-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

@tagName("")
export default class GroupsFormInteractionFields extends Component {
  aliasLevelOptions = [
    { name: i18n("groups.alias_levels.nobody"), value: 0 },
    { name: i18n("groups.alias_levels.only_admins"), value: 1 },
    { name: i18n("groups.alias_levels.mods_and_admins"), value: 2 },
    { name: i18n("groups.alias_levels.members_mods_and_admins"), value: 3 },
    { name: i18n("groups.alias_levels.owners_mods_and_admins"), value: 4 },
    { name: i18n("groups.alias_levels.everyone"), value: 99 },
  ];

  watchingNotificationLevel = NotificationLevels.WATCHING;

  @computed("model.messageable_level", "aliasLevelOptions.firstObject.value")
  get messageableLevel() {
    return (
      this.model?.messageable_level ||
      this.aliasLevelOptions?.firstObject?.value
    );
  }

  @computed("model.mentionable_level", "aliasLevelOptions.firstObject.value")
  get mentionableLevel() {
    return (
      this.model?.mentionable_level ||
      this.aliasLevelOptions?.firstObject?.value
    );
  }

  @computed("model.default_notification_level", "watchingNotificationLevel")
  get defaultNotificationLevel() {
    if (
      Object.values(NotificationLevels).includes(
        this.model?.default_notification_level
      )
    ) {
      return this.model?.default_notification_level;
    }
    return this.watchingNotificationLevel;
  }

  @computed("siteSettings.email_in", "model.automatic", "currentUser.admin")
  get showEmailSettings() {
    return (
      this.siteSettings?.email_in &&
      this.currentUser?.admin &&
      !this.model?.automatic
    );
  }

  @computed(
    "model.isCreated",
    "model.can_admin_group",
    "currentUser.can_create_group"
  )
  get canAdminGroup() {
    return (
      (!this.model?.isCreated && this.currentUser?.can_create_group) ||
      (this.model?.isCreated && this.model?.can_admin_group)
    );
  }

  <template>
    <div ...attributes>
      <div class="control-group">
        <label class="control-label">
          {{i18n "groups.manage.interaction.posting"}}
        </label>
        <label for="alias">{{i18n "groups.alias_levels.mentionable"}}</label>

        <ComboBox
          @name="alias"
          @valueProperty="value"
          @value={{this.mentionableLevel}}
          @content={{this.aliasLevelOptions}}
          @onChange={{fn (mut this.model.mentionable_level)}}
          class="groups-form-mentionable-level"
        />
      </div>

      <div class="control-group">
        <label for="alias">{{i18n "groups.alias_levels.messageable"}}</label>

        <ComboBox
          @name="alias"
          @valueProperty="value"
          @value={{this.messageableLevel}}
          @content={{this.aliasLevelOptions}}
          @onChange={{fn (mut this.model.messageable_level)}}
          class="groups-form-messageable-level"
        />
      </div>

      {{#if this.canAdminGroup}}
        <div class="control-group">
          <label>
            <Input
              @type="checkbox"
              @checked={{this.model.publish_read_state}}
              class="groups-form-publish-read-state"
            />

            {{i18n "admin.groups.manage.interaction.publish_read_state"}}
          </label>
        </div>
      {{/if}}

      {{#if this.showEmailSettings}}
        <div class="control-group">
          <label class="control-label">
            {{i18n "admin.groups.manage.interaction.email"}}
          </label>
          <label for="incoming_email">
            {{i18n "admin.groups.manage.interaction.incoming_email"}}
          </label>

          <DTextField
            @name="incoming_email"
            @value={{this.model.incoming_email}}
            @placeholderKey="admin.groups.manage.interaction.incoming_email_placeholder"
            class="input-xxlarge groups-form-incoming-email"
          />

          <DTooltip
            @icon="circle-info"
            @content={{i18n
              "admin.groups.manage.interaction.incoming_email_tooltip"
            }}
          />

          <span>
            <PluginOutlet
              @name="group-email-in"
              @connectorTagName="div"
              @outletArgs={{lazyHash model=this.model}}
            />
          </span>
        </div>
      {{/if}}

      <label class="control-label">
        {{i18n "groups.manage.interaction.notification"}}
      </label>

      <div class="control-group">
        <label>{{i18n "groups.notification_level"}}</label>

        <NotificationsButton
          @value={{this.defaultNotificationLevel}}
          @options={{hash i18nPrefix="groups.notifications"}}
          @onChange={{fn (mut this.model.default_notification_level)}}
          class="groups-form-default-notification-level"
        />
      </div>

      <span>
        <PluginOutlet
          @name="groups-interaction-custom-options"
          @connectorTagName="div"
          @outletArgs={{lazyHash model=this.model}}
        />
      </span>
    </div>
  </template>
}
