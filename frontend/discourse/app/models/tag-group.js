import RestCompatModel from "discourse/data/rest-compat";
import { TagGroupSchema } from "discourse/data/schemas/tag-group";
import { defineFieldForwarders } from "discourse/data/warp-rest-model";
import PermissionType from "discourse/models/permission-type";

export default class TagGroup extends RestCompatModel {
  static type = "tag-group";

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

defineFieldForwarders(TagGroup, TagGroupSchema);
