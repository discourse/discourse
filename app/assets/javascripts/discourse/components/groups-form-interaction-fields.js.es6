import Component from "@ember/component";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Component.extend({
  init() {
    this._super(...arguments);

    this.visibilityLevelOptions = [
      {
        name: I18n.t(
          "admin.groups.manage.interaction.visibility_levels.public"
        ),
        value: 0
      },
      {
        name: I18n.t(
          "admin.groups.manage.interaction.visibility_levels.logged_on_users"
        ),
        value: 1
      },
      {
        name: I18n.t(
          "admin.groups.manage.interaction.visibility_levels.members"
        ),
        value: 2
      },
      {
        name: I18n.t("admin.groups.manage.interaction.visibility_levels.staff"),
        value: 3
      },
      {
        name: I18n.t(
          "admin.groups.manage.interaction.visibility_levels.owners"
        ),
        value: 4
      }
    ];

    this.aliasLevelOptions = [
      { name: I18n.t("groups.alias_levels.nobody"), value: 0 },
      { name: I18n.t("groups.alias_levels.only_admins"), value: 1 },
      { name: I18n.t("groups.alias_levels.mods_and_admins"), value: 2 },
      { name: I18n.t("groups.alias_levels.members_mods_and_admins"), value: 3 },
      { name: I18n.t("groups.alias_levels.owners_mods_and_admins"), value: 4 },
      { name: I18n.t("groups.alias_levels.everyone"), value: 99 }
    ];
  },

  @computed("siteSettings.email_in", "model.automatic", "currentUser.admin")
  showEmailSettings(emailIn, automatic, isAdmin) {
    return emailIn && isAdmin && !automatic;
  }
});
