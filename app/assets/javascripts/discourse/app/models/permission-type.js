import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export function buildPermissionDescription(id) {
  return I18n.t("permission_types." + PermissionType.DESCRIPTION_KEYS[id]);
}

export default class PermissionType extends EmberObject {
  static FULL = 1;
  static CREATE_POST = 2;
  static READONLY = 3;
  static DESCRIPTION_KEYS = {
    1: "full",
    2: "create_post",
    3: "readonly",
  };

  @discourseComputed("id")
  description(id) {
    return buildPermissionDescription(id);
  }
}
