import PermissionType from "discourse/models/permission-type";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import discourseComputed from "discourse-common/utils/decorators";
import { not } from "@ember/object/computed";

export default buildCategoryPanel("security", {
  selectedGroup: null,
  noGroupSelected: not("selectedGroup"),

  @discourseComputed("category.permissions.@each.permission_type")
  everyonePermission(permissions) {
    return permissions.findBy("group_name", "everyone");
  },

  @discourseComputed("category.permissions.@each.permission_type")
  everyoneGrantedFull() {
    return (
      this.everyonePermission &&
      this.everyonePermission.permission_type === PermissionType.FULL
    );
  },

  @discourseComputed("everyonePermission")
  minimumPermission(everyonePermission) {
    return everyonePermission
      ? everyonePermission.permission_type
      : PermissionType.READONLY;
  },

  actions: {
    onSelectGroup(group_name) {
      this.category.addPermission({
        group_name,
        permission_type: this.minimumPermission,
      });
    },
  },
});
