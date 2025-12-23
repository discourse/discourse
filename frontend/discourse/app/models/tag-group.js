import { computed } from "@ember/object";
import PermissionType from "discourse/models/permission-type";
import RestModel from "discourse/models/rest";

export default class TagGroup extends RestModel {
  @computed("permissions")
  get permissionName() {
    if (!this.permissions) {
      return "public";
    }

    if (this.permissions[0] === PermissionType.FULL) {
      return "public";
    } else if (this.permissions[0] === PermissionType.READONLY) {
      return "visible";
    } else {
      return "private";
    }
  }
}
