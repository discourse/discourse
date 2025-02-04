import discourseComputed from "discourse/lib/decorators";
import PermissionType from "discourse/models/permission-type";
import RestModel from "discourse/models/rest";

export default class TagGroup extends RestModel {
  @discourseComputed("permissions")
  permissionName(permissions) {
    if (!permissions) {
      return "public";
    }

    if (permissions[0] === PermissionType.FULL) {
      return "public";
    } else if (permissions[0] === PermissionType.READONLY) {
      return "visible";
    } else {
      return "private";
    }
  }
}
