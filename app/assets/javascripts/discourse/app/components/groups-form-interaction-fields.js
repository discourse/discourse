import Component from "@ember/component";
import { or } from "@ember/object/computed";
import { NotificationLevels } from "discourse/lib/notification-levels";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

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
}
