import PermissionType from "discourse/models/permission-type";
import RestModel from "discourse/models/rest";
import discourseComputed from "discourse-common/utils/decorators";

export default RestModel.extend({
  @discourseComputed("permissions")
  permissionName(permissions) {
    if (!permissions) {
      return "public";
    }

    if (permissions["everyone"] === PermissionType.FULL) {
      return "public";
    } else if (permissions["everyone"] === PermissionType.READONLY) {
      return "visible";
    } else {
      return "private";
    }
  },
});
