import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import PermissionType from "discourse/models/permission-type";
import { on } from "discourse-common/utils/decorators";

export default buildCategoryPanel("security", {
  editingPermissions: false,
  selectedGroup: null,
  selectedPermission: null,
  showPendingGroupChangesAlert: false,
  interactedWithDropdowns: false,

  @on("init")
  _setup() {
    this.setProperties({
      selectedGroup: this.get("category.availableGroups.firstObject"),
      selectedPermission: this.get(
        "category.availablePermissions.firstObject.id"
      )
    });
  },

  @on("init")
  _registerValidator() {
    this.registerValidator(() => {
      if (
        !this.showPendingGroupChangesAlert &&
        this.interactedWithDropdowns &&
        this.activeTab
      ) {
        this.set("showPendingGroupChangesAlert", true);
        return true;
      }
    });
  },

  actions: {
    onSelectGroup(selectedGroup) {
      this.setProperties({
        interactedWithDropdowns: true,
        selectedGroup
      });
    },

    onSelectPermission(selectedPermission) {
      this.setProperties({
        interactedWithDropdowns: true,
        selectedPermission
      });
    },

    editPermissions() {
      if (!this.get("category.is_special")) {
        this.set("editingPermissions", true);
      }
    },

    addPermission(group, id) {
      if (!this.get("category.is_special")) {
        this.category.addPermission({
          group_name: group + "",
          permission: PermissionType.create({ id: parseInt(id, 10) })
        });
      }

      this.setProperties({
        selectedGroup: this.get("category.availableGroups.firstObject"),
        showPendingGroupChangesAlert: false,
        interactedWithDropdowns: false
      });
    },

    removePermission(permission) {
      if (!this.get("category.is_special")) {
        this.category.removePermission(permission);
      }
    }
  }
});
