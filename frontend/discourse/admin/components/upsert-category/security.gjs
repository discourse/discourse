import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import UpsertCategoryPermissionRow from "discourse/admin/components/upsert-category/permission-row";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { AUTO_GROUPS } from "discourse/lib/constants";
import Category from "discourse/models/category";
import PermissionType from "discourse/models/permission-type";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class UpsertCategorySecurity extends Component {
  @service site;

  get permissions() {
    return (
      this.args.transientData?.permissions ?? this.args.category.permissions
    );
  }

  get parentCategoryId() {
    return (
      this.args.transientData?.parent_category_id ??
      this.args.category.parent_category_id
    );
  }

  get parentCategory() {
    const parentId = this.parentCategoryId;
    if (!parentId) {
      return null;
    }
    return Category.findById(parentId);
  }

  get parentPermissions() {
    const parent = this.parentCategory;
    if (!parent) {
      return null;
    }
    // Try permissions first (set up by setupGroupsAndPermissions),
    // fall back to group_permissions (raw data from server)
    return parent.permissions?.length
      ? parent.permissions
      : parent.group_permissions;
  }

  get parentIsRestricted() {
    const parentPerms = this.parentPermissions;
    if (!parentPerms?.length) {
      return false;
    }

    return !parentPerms.some((p) => p.group_id === AUTO_GROUPS.everyone.id);
  }

  get availableGroups() {
    const permissions = this.permissions || [];
    const permissionGroupIds = new Set(permissions.map((p) => p.group_id));

    let groups = this.site.groups.filter((g) => !permissionGroupIds.has(g.id));

    if (this.parentIsRestricted) {
      const parentGroupIds = new Set(
        this.parentPermissions.map((p) => p.group_id)
      );
      groups = groups.filter((g) => parentGroupIds.has(g.id));
    }

    return groups;
  }

  get hasAvailableGroups() {
    return this.availableGroups.length > 0;
  }

  get allParentGroupsUsed() {
    return this.parentIsRestricted && !this.hasAvailableGroups;
  }

  get everyonePermission() {
    return this.permissions?.find(
      (p) => p.group_id === AUTO_GROUPS.everyone.id
    );
  }

  get everyoneAccessMessageKey() {
    const permissionType = this.everyonePermission?.permission_type;
    if (permissionType === PermissionType.FULL) {
      return "category.permissions.everyone_full_access";
    } else if (permissionType === PermissionType.CREATE_POST) {
      return "category.permissions.everyone_reply_access";
    } else {
      return "category.permissions.everyone_see_access";
    }
  }

  get minimumPermission() {
    return this.everyonePermission?.permission_type ?? PermissionType.READONLY;
  }

  get panelClass() {
    const isActive = this.args.selectedTab === "security" ? "active" : "";
    return `edit-category-tab edit-category-tab-security ${isActive}`;
  }

  #setFormPermissions(permissions) {
    this.args.form.set("permissions", permissions);
  }

  @action
  onSelectGroup(groupId) {
    const group = this.site.groups.find((g) => g.id === groupId);
    const newPermissions = [
      ...(this.permissions || []),
      {
        group_name: group?.name,
        group_id: groupId,
        permission_type: this.minimumPermission,
      },
    ];
    this.#setFormPermissions(newPermissions);
  }

  @action
  onRemovePermission(groupId) {
    const newPermissions = (this.permissions || []).filter(
      (p) => p.group_id !== groupId
    );
    this.#setFormPermissions(newPermissions);
  }

  @action
  onUpdatePermission(groupId, permissionType) {
    const newPermissions = (this.permissions || []).map((p) =>
      p.group_id === groupId ? { ...p, permission_type: permissionType } : p
    );
    this.#setFormPermissions(newPermissions);
  }

  @action
  onChangeEveryonePermission(everyonePermissionType) {
    const newPermissions = (this.permissions || []).map((permission) => {
      if (permission.group_id === AUTO_GROUPS.everyone.id) {
        return permission;
      }

      if (everyonePermissionType < permission.permission_type) {
        return { ...permission, permission_type: everyonePermissionType };
      }

      return permission;
    });
    this.#setFormPermissions(newPermissions);
  }

  <template>
    <div class={{this.panelClass}}>
      {{#if @category.is_special}}
        {{#if @category.isUncategorizedCategory}}
          <@form.Alert @type="warning">
            {{i18n "category.uncategorized_security_warning"}}
          </@form.Alert>
        {{else}}
          <@form.Alert @type="warning">
            {{i18n "category.special_warning"}}
          </@form.Alert>
        {{/if}}
      {{/if}}

      {{#unless @category.is_special}}
        <@form.Container>
          <div class="category-permissions-table">
            <div class="permission-row row-header">
              <span class="group-name">{{i18n
                  "category.permissions.group"
                }}</span>
              <span class="options">
                <span class="cell">{{i18n "category.permissions.see"}}</span>
                <span class="cell">{{i18n "category.permissions.reply"}}</span>
                <span class="cell">{{i18n "category.permissions.create"}}</span>
                <span class="cell"></span>
              </span>
            </div>
            {{#each this.permissions as |p|}}
              <UpsertCategoryPermissionRow
                @groupId={{p.group_id}}
                @groupName={{p.group_name}}
                @type={{p.permission_type}}
                @everyonePermission={{this.everyonePermission}}
                @onChangeEveryonePermission={{this.onChangeEveryonePermission}}
                @onRemovePermission={{this.onRemovePermission}}
                @onUpdatePermission={{this.onUpdatePermission}}
              />
            {{/each}}

            {{#unless this.permissions}}
              <div class="permission-row row-empty">
                {{i18n "category.permissions.no_groups_selected"}}
              </div>
            {{/unless}}

            {{#if this.hasAvailableGroups}}
              <PluginOutlet
                @name="category-security-permissions-add-group"
                @outletArgs={{lazyHash
                  category=@category
                  availableGroups=this.availableGroups
                  onSelectGroup=this.onSelectGroup
                }}
                @defaultGlimmer={{true}}
              >
                <div class="add-group">
                  <span class="group-name">
                    <ComboBox
                      @content={{this.availableGroups}}
                      @onChange={{this.onSelectGroup}}
                      @value={{null}}
                      @valueProperty="id"
                      @nameProperty="name"
                      @options={{hash none="category.security_add_group"}}
                      class="available-groups"
                    />
                  </span>
                </div>
              </PluginOutlet>
            {{/if}}
          </div>

          {{#if this.allParentGroupsUsed}}
            <@form.Alert @type="warning">
              {{i18n "category.permissions.all_parent_groups_used"}}
            </@form.Alert>
          {{/if}}

          <@form.Alert @type="warning">
            {{#if this.everyonePermission}}
              {{i18n this.everyoneAccessMessageKey}}
            {{else}}
              {{i18n "category.permissions.specific_groups_have_access"}}
            {{/if}}
          </@form.Alert>
        </@form.Container>
      {{/unless}}

      <PluginOutlet
        @name="category-custom-security"
        @outletArgs={{lazyHash category=@category}}
      />
    </div>
  </template>
}
