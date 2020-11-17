import I18n from "I18n";
import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import PermissionType from "discourse/models/permission-type";
import { equal, alias } from "@ember/object/computed";

const EVERYONE = "everyone";

export default Component.extend({
  classNames: ["permission-row", "row-body"],
  canCreate: equal("type", PermissionType.FULL),
  everyonePermissionType: alias("everyonePermission.permission_type"),

  @discourseComputed("type")
  canReply(value) {
    return (
      value === PermissionType.CREATE_POST || value === PermissionType.FULL
    );
  },

  @discourseComputed("type")
  canReplyIcon() {
    return this.canReply ? "check" : "times";
  },

  @discourseComputed("type")
  canCreateIcon() {
    return this.canCreate ? "check" : "times";
  },

  @observes("everyonePermissionType")
  inheritFromEveryone() {
    if (this.group_name === EVERYONE) {
      return;
    }

    // groups cannot have a lesser permission than "everyone"
    if (this.everyonePermissionType < this.type) {
      this.updatePermission(this.everyonePermissionType);
    }
  },

  @discourseComputed("everyonePermissionType", "type")
  seeTooltip(everyonePermissionType) {
    if (
      this.group_name !== EVERYONE &&
      everyonePermissionType &&
      everyonePermissionType < PermissionType.READONLY
    ) {
      return I18n.t("category.permissions.inherited");
    }
    return I18n.t("category.permissions.grant_see");
  },

  @discourseComputed("everyonePermissionType", "type")
  replyTooltip(everyonePermissionType) {
    if (
      this.group_name !== EVERYONE &&
      everyonePermissionType &&
      everyonePermissionType < PermissionType.CREATE_POST
    ) {
      return I18n.t("category.permissions.inherited");
    }
    return I18n.t("category.permissions.grant_reply");
  },

  @discourseComputed("everyonePermissionType", "type")
  createTooltip(everyonePermissionType) {
    if (
      this.group_name !== EVERYONE &&
      everyonePermissionType &&
      everyonePermissionType === PermissionType.FULL
    ) {
      return I18n.t("category.permissions.inherited");
    }
    return I18n.t("category.permissions.grant_full");
  },

  updatePermission(type) {
    this.category.updatePermission(this.group_name, type);
  },

  actions: {
    removeRow() {
      this.category.removePermission(this.group_name);
    },

    setPermissionSee() {
      if (
        this.group_name !== EVERYONE &&
        this.everyonePermissionType < PermissionType.READONLY
      ) {
        return;
      }
      this.updatePermission(PermissionType.READONLY);
    },

    setPermissionReply() {
      if (
        this.group_name !== EVERYONE &&
        this.everyonePermissionType < PermissionType.CREATE_POST
      ) {
        return;
      }

      this.updatePermission(PermissionType.CREATE_POST);
    },

    setPermissionFull() {
      this.updatePermission(PermissionType.FULL);
    },
  },
});
