import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { not } from "@ember/object/computed";
import { service } from "@ember/service";
import { buildCategoryPanel } from "discourse/admin/components/edit-category-panel";
import CategoryPermissionRow from "discourse/components/category-permission-row";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { AUTO_GROUPS } from "discourse/lib/constants";
import PermissionType from "discourse/models/permission-type";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class EditCategorySecurity extends buildCategoryPanel(
  "security"
) {
  @service site;

  selectedGroup = null;

  @not("selectedGroup") noGroupSelected;

  get everyonePermission() {
    return this.category.permissions.find(
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

  @action
  onSelectGroup(group_name) {
    const group = this.site.groups.find((g) => g.name === group_name);
    this.category.addPermission({
      group_name,
      group_id: group?.id,
      permission_type: this.minimumPermission,
    });
  }

  @action
  onChangeEveryonePermission(everyonePermissionType) {
    this.category.permissions.forEach((permission, idx) => {
      if (permission.group_id === AUTO_GROUPS.everyone.id) {
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

  <template>
    <section class="field">
      {{#if this.category.is_special}}
        {{#if this.category.isUncategorizedCategory}}
          <p class="warning">{{i18n
              "category.uncategorized_security_warning"
            }}</p>
        {{else}}
          <p class="warning">{{i18n "category.special_warning"}}</p>
        {{/if}}
      {{/if}}

      {{#unless this.category.is_special}}
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
          {{#each this.category.permissions as |p|}}
            <CategoryPermissionRow
              @groupId={{p.group_id}}
              @groupName={{p.group_name}}
              @type={{p.permission_type}}
              @category={{this.category}}
              @everyonePermission={{this.everyonePermission}}
              @onChangeEveryonePermission={{this.onChangeEveryonePermission}}
            />
          {{/each}}

          {{#unless this.category.permissions}}
            <div class="permission-row row-empty">
              {{i18n "category.permissions.no_groups_selected"}}
            </div>
          {{/unless}}

          {{#if this.category.availableGroups}}
            <PluginOutlet
              @name="category-security-permissions-add-group"
              @outletArgs={{lazyHash
                category=this.category
                availableGroups=this.category.availableGroups
                onSelectGroup=this.onSelectGroup
              }}
              @defaultGlimmer={{true}}
            >
              <div class="add-group">
                <span class="group-name">
                  <ComboBox
                    @content={{this.category.availableGroups}}
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
          <p class="warning">{{i18n
              "category.permissions.everyone_has_access"
            }}</p>
        {{/if}}
      {{/unless}}
    </section>

    <section>
      <PluginOutlet
        @name="category-custom-security"
        @outletArgs={{lazyHash category=this.category}}
      />
    </section>
  </template>
}
