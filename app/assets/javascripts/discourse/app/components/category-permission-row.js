import Component from "@ember/component";
import { action } from "@ember/object";
import { alias, equal } from "@ember/object/computed";
import PermissionType from "discourse/models/permission-type";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

const EVERYONE = "everyone";

export default Component.extend({
  tagName: "tr",
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

  @discourseComputed("category.can_moderate")
  canModerateIcon() {
    return this.category.can_moderate ? "check-square" : "far-square";
  },

  @discourseComputed("category.can_moderate")
  moderateGranted() {
    return this.category.can_moderate ? "moderate-granted" : "";
  },

  @discourseComputed("group_name")
  moderateDisabled() {
    return this.group_name === EVERYONE;
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

    setPermissionModerate() {
      let reviewableByGroupNames =
        this.category.reviewable_by_group_names || [];

      if (reviewableByGroupNames.includes(this.group_name)) {
        reviewableByGroupNames = reviewableByGroupNames.filter(
          (name) => name !== this.group_name
        );
      } else {
        reviewableByGroupNames.push(this.group_name);
      }

      this.category.set("reviewable_by_group_names", reviewableByGroupNames);
    },
  },
});
