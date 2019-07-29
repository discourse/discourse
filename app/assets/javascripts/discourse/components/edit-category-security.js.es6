import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import PermissionType from "discourse/models/permission-type";
import { on } from "ember-addons/ember-computed-decorators";

export default buildCategoryPanel("security", {
  editingPermissions: false,
  selectedGroup: null,
  selectedPermission: null,
  showPendingGroupChangesAlert: false,
  interactedWithDropdowns: false,

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
    onDropdownChange() {
      this.set("interactedWithDropdowns", true);
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
          permission: PermissionType.create({ id: parseInt(id) })
        });
      }

      this.set(
        "selectedGroup",
        this.get("category.availableGroups.firstObject")
      );
      this.setProperties({
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
