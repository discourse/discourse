import { buildCategoryPanel } from 'discourse/components/edit-category-panel';

export default buildCategoryPanel('security', {
  editingPermissions: false,
  selectedGroup: null,
  selectedPermission: null,

  actions: {
    editPermissions() {
      this.set('editingPermissions', true);
    },

    addPermission(group, id) {
      this.get('category').addPermission({group_name: group + "",
                                       permission: Discourse.PermissionType.create({id})});
    },

    removePermission(permission) {
      this.get('category').removePermission(permission);
    },
  }
});
