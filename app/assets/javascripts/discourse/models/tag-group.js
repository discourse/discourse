import discourseComputed from "discourse-common/utils/decorators";
import RestModel from "discourse/models/rest";
import PermissionType from "discourse/models/permission-type";

export default RestModel.extend({
  @discourseComputed("permissions")
  permissionName(permissions) {
    if (!permissions) return "public";

    if (permissions["everyone"] === PermissionType.FULL) {
      return "public";
    } else if (permissions["everyone"] === PermissionType.READONLY) {
      return "visible";
    } else {
      return "private";
    }
  }
});
