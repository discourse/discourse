import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";
import EmberObject from "@ember/object";

export function buildPermissionDescription(id) {
  let key = "";

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

const PermissionType = EmberObject.extend({
  @discourseComputed("id")
  description(id) {
    return buildPermissionDescription(id);
  }
});

PermissionType.FULL = 1;
PermissionType.CREATE_POST = 2;
PermissionType.READONLY = 3;

export default PermissionType;
