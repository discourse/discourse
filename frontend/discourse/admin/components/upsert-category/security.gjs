import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CategoryPermissionRow from "discourse/components/category-permission-row";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { AUTO_GROUPS } from "discourse/lib/constants";
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

  get availableGroups() {
    const permissions = this.permissions || [];
    const permissionGroupIds = new Set(permissions.map((p) => p.group_id));
    return this.site.groups
      .filter((g) => !permissionGroupIds.has(g.id))
      .map((g) => g.name);
  }

  get everyonePermission() {
    return this.permissions?.find(
      (p) => p.group_id === AUTO_GROUPS.everyone.id
    );
  }

  get everyoneGrantedFull() {
    return (
      this.everyonePermission &&
      this.everyonePermission.permission_type === PermissionType.FULL
    );
  }

  get minimumPermission() {
    return this.everyonePermission
      ? this.everyonePermission.permission_type
      : PermissionType.READONLY;
  }

  get panelClass() {
    const isActive = this.args.selectedTab === "security" ? "active" : "";
    return `edit-category-tab edit-category-tab-security ${isActive}`;
  }

  #setFormPermissions(permissions) {
    this.args.form.set("permissions", permissions);
  }

  @action
  onSelectGroup(group_name) {
    const group = this.site.groups.find((g) => g.name === group_name);
    const newPermissions = [
      ...(this.permissions || []),
      {
        group_name,
        group_id: group?.id,
        permission_type: this.minimumPermission,
      },
    ];
    this.#setFormPermissions(newPermissions);
  }

  @action
  onRemovePermission(groupName) {
    const newPermissions = (this.permissions || []).filter(
      (p) => p.group_name !== groupName
    );
    this.#setFormPermissions(newPermissions);
  }

  @action
  onUpdatePermission(groupName, permissionType) {
    const newPermissions = (this.permissions || []).map((p) =>
      p.group_name === groupName ? { ...p, permission_type: permissionType } : p
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
              <CategoryPermissionRow
                @groupId={{p.group_id}}
                @groupName={{p.group_name}}
                @type={{p.permission_type}}
                @category={{@category}}
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

            {{#if this.availableGroups}}
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
                      @valueProperty={{null}}
                      @nameProperty={{null}}
                      @options={{hash none="category.security_add_group"}}
                      class="available-groups"
                    />
                  </span>
                </div>
              </PluginOutlet>
            {{/if}}
          </div>

          {{#if this.everyoneGrantedFull}}
            <@form.Alert @type="warning">
              {{i18n "category.permissions.everyone_has_access"}}
            </@form.Alert>
          {{else}}
            <@form.Alert @type="warning">
              {{i18n "category.permissions.specific_groups_have_access"}}
            </@form.Alert>
          {{/if}}
        </@form.Container>
      {{/unless}}

      <PluginOutlet
        @name="category-custom-security"
        @outletArgs={{lazyHash category=@category}}
      />
    </div>
  </template>
}
