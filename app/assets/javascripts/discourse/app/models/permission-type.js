import EmberObject from "@ember/object";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";

export function buildPermissionDescription(id) {
  return I18n.t("permission_types." + PermissionType.DESCRIPTION_KEYS[id]);
}

const PermissionType = EmberObject.extend({
  @discourseComputed("id")
  description(id) {
    return buildPermissionDescription(id);
  },
});

PermissionType.FULL = 1;
PermissionType.CREATE_POST = 2;
PermissionType.READONLY = 3;
PermissionType.DESCRIPTION_KEYS = {
  1: "full",
  2: "create_post",
  3: "readonly",
};

export default PermissionType;
