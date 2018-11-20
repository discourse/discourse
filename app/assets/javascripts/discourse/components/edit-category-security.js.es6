import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import PermissionType from "discourse/models/permission-type";

export default buildCategoryPanel("security", {
  editingPermissions: false,
  selectedGroup: null,
  selectedPermission: null,

  actions: {
    editPermissions() {
      if (!this.get("category.is_special")) {
        this.set("editingPermissions", true);
      }
    },

    addPermission(group, id) {
      if (!this.get("category.is_special")) {
        this.get("category").addPermission({
          group_name: group + "",
          permission: PermissionType.create({ id: parseInt(id) })
        });
      }

      this.set(
        "selectedGroup",
        this.get("category.availableGroups.firstObject")
      );
    },

    removePermission(permission) {
      if (!this.get("category.is_special")) {
        this.get("category").removePermission(permission);
      }
    }
  }
});
