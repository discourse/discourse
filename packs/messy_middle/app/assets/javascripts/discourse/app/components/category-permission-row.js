import { action } from "@ember/object";
import { alias, equal } from "@ember/object/computed";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import PermissionType from "discourse/models/permission-type";

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
    return this.canReply ? "check-square" : "far-square";
  },

  @discourseComputed("type")
  canCreateIcon() {
    return this.canCreate ? "check-square" : "far-square";
  },

  @discourseComputed("type")
  replyGranted() {
    return this.type <= PermissionType.CREATE_POST ? "reply-granted" : "";
  },

  @discourseComputed("type")
  createGranted() {
    return this.type === PermissionType.FULL ? "create-granted" : "";
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
  replyDisabled(everyonePermissionType) {
    if (
      this.group_name !== EVERYONE &&
      everyonePermissionType &&
      everyonePermissionType <= PermissionType.CREATE_POST
    ) {
      return true;
    }
    return false;
  },

  @discourseComputed("replyDisabled")
  replyTooltip(replyDisabled) {
    return replyDisabled
      ? I18n.t("category.permissions.inherited")
      : I18n.t("category.permissions.toggle_reply");
  },

  @discourseComputed("everyonePermissionType", "type")
  createDisabled(everyonePermissionType) {
    if (
      this.group_name !== EVERYONE &&
      everyonePermissionType &&
      everyonePermissionType === PermissionType.FULL
    ) {
      return true;
    }
    return false;
  },

  @discourseComputed("createDisabled")
  createTooltip(createDisabled) {
    return createDisabled
      ? I18n.t("category.permissions.inherited")
      : I18n.t("category.permissions.toggle_full");
  },

  updatePermission(type) {
    this.category.updatePermission(this.group_name, type);
  },

  @action
  removeRow(event) {
    event?.preventDefault();
    this.category.removePermission(this.group_name);
  },

  actions: {
    setPermissionReply() {
      if (this.type <= PermissionType.CREATE_POST) {
        this.updatePermission(PermissionType.READONLY);
      } else {
        this.updatePermission(PermissionType.CREATE_POST);
      }
    },

    setPermissionFull() {
      if (
        this.group_name !== EVERYONE &&
        this.everyonePermissionType === PermissionType.FULL
      ) {
        return;
      }

      if (this.type === PermissionType.FULL) {
        this.updatePermission(PermissionType.CREATE_POST);
      } else {
        this.updatePermission(PermissionType.FULL);
      }
    },
  },
});
