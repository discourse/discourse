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

    onDropdownChange() {
      Ember.run.later(() => {
        this.setPendingGroupPermission(this.selectedGroup);
      }, 20);
    },

    addPermission(group, id) {
      if (!this.get("category.is_special")) {
        this.category.addPermission({
          group_name: group + "",
          permission: PermissionType.create({ id: parseInt(id) })
        });
      }

      this.set(
        "selectedGroup",
        this.get("category.availableGroups.firstObject")
      );
      this.setPendingGroupPermission(null);
    },

    removePermission(permission) {
      if (!this.get("category.is_special")) {
        this.category.removePermission(permission);
      }
    }
  }
});
