import discourseComputed from "discourse-common/utils/decorators";

const PermissionType = Discourse.Model.extend({
  @discourseComputed("id")
  description(id) {
    var key = "";

    switch (id) {
      case 1:
        key = "full";
        break;
      case 2:
        key = "create_post";
        break;
      case 3:
        key = "readonly";
        break;
    }
    return I18n.t("permission_types." + key);
  }
});

PermissionType.FULL = 1;
PermissionType.CREATE_POST = 2;
PermissionType.READONLY = 3;

export default PermissionType;
