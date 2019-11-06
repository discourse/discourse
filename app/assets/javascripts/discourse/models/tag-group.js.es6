import RestModel from "discourse/models/rest";
import computed from "ember-addons/ember-computed-decorators";
import PermissionType from "discourse/models/permission-type";

export default RestModel.extend({
  @computed("permissions")
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
