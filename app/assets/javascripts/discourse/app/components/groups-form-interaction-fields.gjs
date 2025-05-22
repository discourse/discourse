import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { or } from "@ember/object/computed";
import PluginOutlet from "discourse/components/plugin-outlet";
import TextField from "discourse/components/text-field";
import lazyHash from "discourse/helpers/lazy-hash";
import discourseComputed from "discourse/lib/decorators";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import NotificationsButton from "select-kit/components/notifications-button";
import DTooltip from "float-kit/components/d-tooltip";

export default class GroupsFormInteractionFields extends Component {
  @or(
    "model.members_visibility_level",
    "visibilityLevelOptions.firstObject.value"
  )
  membersVisibilityLevel;

  @or("model.messageable_level", "aliasLevelOptions.firstObject.value")
  messageableLevel;

  @or("model.mentionable_level", "aliasLevelOptions.firstObject.value")
  mentionableLevel;

  visibilityLevelOptions = [
    {
      name: i18n("admin.groups.manage.interaction.visibility_levels.public"),
      value: 0,
    },
    {
      name: i18n(
        "admin.groups.manage.interaction.visibility_levels.logged_on_users"
      ),
      value: 1,
    },
    {
      name: i18n("admin.groups.manage.interaction.visibility_levels.members"),
      value: 2,
    },
    {
      name: i18n("admin.groups.manage.interaction.visibility_levels.staff"),
      value: 3,
    },
    {
      name: i18n("admin.groups.manage.interaction.visibility_levels.owners"),
      value: 4,
    },
  ];

  aliasLevelOptions = [
    { name: i18n("groups.alias_levels.nobody"), value: 0 },
    { name: i18n("groups.alias_levels.only_admins"), value: 1 },
    { name: i18n("groups.alias_levels.mods_and_admins"), value: 2 },
    { name: i18n("groups.alias_levels.members_mods_and_admins"), value: 3 },
    { name: i18n("groups.alias_levels.owners_mods_and_admins"), value: 4 },
    { name: i18n("groups.alias_levels.everyone"), value: 99 },
  ];

  watchingNotificationLevel = NotificationLevels.WATCHING;

  @discourseComputed(
    "model.default_notification_level",
    "watchingNotificationLevel"
  )
  defaultNotificationLevel(
    defaultNotificationLevel,
    watchingNotificationLevel
  ) {
    if (Object.values(NotificationLevels).includes(defaultNotificationLevel)) {
      return defaultNotificationLevel;
    }
    return watchingNotificationLevel;
  }

  @discourseComputed(
    "siteSettings.email_in",
    "model.automatic",
    "currentUser.admin"
  )
  showEmailSettings(emailIn, automatic, isAdmin) {
    return emailIn && isAdmin && !automatic;
  }

  @discourseComputed(
    "model.isCreated",
    "model.can_admin_group",
    "currentUser.can_create_group"
  )
  canAdminGroup(isCreated, canAdmin, canCreate) {
    return (!isCreated && canCreate) || (isCreated && canAdmin);
  }

  @discourseComputed("membersVisibilityLevel")
  membersVisibilityPrivate(membersVisibilityLevel) {
    return (
      membersVisibilityLevel !== this.visibilityLevelOptions.firstObject.value
    );
  }

  <template>
    {{#if this.canAdminGroup}}
      <div class="control-group">
        <label class="control-label">
          {{i18n "admin.groups.manage.interaction.visibility"}}
        </label>
        <label>
          {{i18n "admin.groups.manage.interaction.visibility_levels.title"}}
        </label>

        <ComboBox
          @name="alias"
          @valueProperty="value"
          @value={{this.model.visibility_level}}
          @content={{this.visibilityLevelOptions}}
          @onChange={{fn (mut this.model.visibility_level)}}
          @options={{hash castInteger=true}}
          class="groups-form-visibility-level"
        />

        <div class="control-instructions">
          {{i18n
            "admin.groups.manage.interaction.visibility_levels.description"
          }}
        </div>
      </div>

      <div class="control-group">
        <label>
          {{i18n
            "admin.groups.manage.interaction.members_visibility_levels.title"
          }}
        </label>

        <ComboBox
          @name="alias"
          @valueProperty="value"
          @value={{this.membersVisibilityLevel}}
          @content={{this.visibilityLevelOptions}}
          @onChange={{fn (mut this.model.members_visibility_level)}}
          class="groups-form-members-visibility-level"
        />

        {{#if this.membersVisibilityPrivate}}
          <div class="control-instructions">
            {{i18n
              "admin.groups.manage.interaction.members_visibility_levels.description"
            }}
          </div>
        {{/if}}
      </div>
    {{/if}}

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

        <TextField
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
  </template>
}
