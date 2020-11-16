import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import PermissionType from "discourse/models/permission-type";
import { equal, alias } from "@ember/object/computed";

const EVERYONE = "everyone";

export default Component.extend({
  classNames: ["permission-row"],
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
  updatePerms() {
    if (this.group_name === EVERYONE) {
      return;
    }

    // groups cannot have a permission level lower than the "everyone" special group
    if (this.everyonePermissionType < this.type) {
      this.updatePermission(this.everyonePermissionType);
    }
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
