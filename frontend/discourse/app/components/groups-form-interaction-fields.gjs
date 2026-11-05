import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { get } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
import { NotificationLevels } from "discourse/lib/notification-levels";
import ComboBox from "discourse/select-kit/components/combo-box";
import NotificationsButton from "discourse/select-kit/components/notifications-button";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default class GroupsFormInteractionFields extends Component {
  @service currentUser;
  @service siteSettings;

  aliasLevelOptions = [
    { name: i18n("groups.alias_levels.nobody"), value: 0 },
    { name: i18n("groups.alias_levels.only_admins"), value: 1 },
    { name: i18n("groups.alias_levels.mods_and_admins"), value: 2 },
    { name: i18n("groups.alias_levels.members_mods_and_admins"), value: 3 },
    { name: i18n("groups.alias_levels.owners_mods_and_admins"), value: 4 },
    { name: i18n("groups.alias_levels.everyone"), value: 99 },
  ];

  get messageableLevel() {
    return (
      get(this.args.model, "messageable_level") ||
      this.aliasLevelOptions[0].value
    );
  }

  get mentionableLevel() {
    return (
      get(this.args.model, "mentionable_level") ||
      this.aliasLevelOptions[0].value
    );
  }

  get defaultNotificationLevel() {
    const level = get(this.args.model, "default_notification_level");
    return Object.values(NotificationLevels).includes(level)
      ? level
      : NotificationLevels.WATCHING;
  }

  get showEmailSettings() {
    return this.siteSettings.email_in && this.currentUser?.admin;
  }

  get canAdminGroup() {
    return (
      (!this.args.model?.isCreated && this.currentUser?.can_create_group) ||
      (this.args.model?.isCreated && this.args.model?.can_admin_group)
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
          class="groups-form-mentionable-level"
          @content={{this.aliasLevelOptions}}
          @name="alias"
          @onChange={{fn (mut @model.mentionable_level)}}
          @value={{this.mentionableLevel}}
          @valueProperty="value"
        />
      </div>

      <div class="control-group">
        <label for="alias">{{i18n "groups.alias_levels.messageable"}}</label>

        <ComboBox
          class="groups-form-messageable-level"
          @content={{this.aliasLevelOptions}}
          @name="alias"
          @onChange={{fn (mut @model.messageable_level)}}
          @value={{this.messageableLevel}}
          @valueProperty="value"
        />
      </div>

      {{#if this.canAdminGroup}}
        <div class="control-group">
          <label>
            <Input
              class="groups-form-publish-read-state"
              @checked={{@model.publish_read_state}}
              @type="checkbox"
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
            class="input-xxlarge groups-form-incoming-email"
            @name="incoming_email"
            @placeholderKey="admin.groups.manage.interaction.incoming_email_placeholder"
            @value={{@model.incoming_email}}
          />

          <DTooltip
            @content={{i18n
              "admin.groups.manage.interaction.incoming_email_tooltip"
            }}
            @icon="circle-info"
          />

          <span>
            <PluginOutlet
              @connectorTagName="div"
              @name="group-email-in"
              @outletArgs={{lazyHash model=@model}}
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
          class="groups-form-default-notification-level"
          @onChange={{fn (mut @model.default_notification_level)}}
          @options={{hash i18nPrefix="groups.notifications"}}
          @value={{this.defaultNotificationLevel}}
        />
      </div>

      <span>
        <PluginOutlet
          @connectorTagName="div"
          @name="groups-interaction-custom-options"
          @outletArgs={{lazyHash model=@model}}
        />
      </span>
    </div>
  </template>
}
