import { action } from "@ember/object";
import { not } from "@ember/object/computed";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import discourseComputed from "discourse/lib/decorators";
import PermissionType from "discourse/models/permission-type";

export default class EditCategorySecurity extends buildCategoryPanel(
  "security"
) {
  selectedGroup = null;

  @not("selectedGroup") noGroupSelected;

  @discourseComputed("category.permissions.@each.permission_type")
  everyonePermission(permissions) {
    return permissions.findBy("group_name", "everyone");
  }

  @discourseComputed("category.permissions.@each.permission_type")
  everyoneGrantedFull() {
    return (
      this.everyonePermission &&
      this.everyonePermission.permission_type === PermissionType.FULL
    );
  }

  @discourseComputed("everyonePermission")
  minimumPermission(everyonePermission) {
    return everyonePermission
      ? everyonePermission.permission_type
      : PermissionType.READONLY;
  }

  @action
  onSelectGroup(group_name) {
    this.category.addPermission({
      group_name,
      permission_type: this.minimumPermission,
    });
  }

  @action
  onChangeEveryonePermission(everyonePermissionType) {
    this.category.permissions.forEach((permission, idx) => {
      if (permission.group_name === "everyone") {
        return;
      }

      if (everyonePermissionType < permission.permission_type) {
        this.category.set(
          `permissions.${idx}.permission_type`,
          everyonePermissionType
        );
      }
    });
  }
}
