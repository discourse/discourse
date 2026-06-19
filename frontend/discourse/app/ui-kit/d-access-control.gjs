import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { AUTO_GROUPS } from "discourse/lib/constants";
import ComboBox from "discourse/select-kit/components/combo-box";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const DEFAULT_PERMISSION = "editor";
const PERMISSIONS = [
  {
    id: "editor",
    name: i18n("access_control.manage.access_permission_editor"),
    description: i18n(
      "access_control.manage.access_permission_editor_description"
    ),
  },
  {
    id: "viewer",
    name: i18n("access_control.manage.access_permission_viewer"),
    description: i18n(
      "access_control.manage.access_permission_viewer_description"
    ),
  },
];
const REMOVE_ACTION = {
  id: "remove",
  name: i18n("access_control.manage.access_permission_remove"),
  description: i18n(
    "access_control.manage.access_permission_remove_description"
  ),
};

export default class DAccessControl extends Component {
  @tracked addingGroup = false;

  constructor() {
    super(...arguments);
    this.permissionOptions = this.buildPermissionOptions();
  }

  buildPermissionOptions() {
    const permissions = this.args.transformPermissionOptions
      ? this.args.transformPermissionOptions(PERMISSIONS)
      : PERMISSIONS;

    return [
      ...permissions,
      {
        ...REMOVE_ACTION,
        classNames:
          "d-access-control__permission-divider d-access-control__permission-remove",
      },
    ];
  }

  get availableGroups() {
    const taken = new Set(this.selectedGroupIds);
    return this.args.groups.filter((group) => !taken.has(group.id));
  }

  get selectedGroupIds() {
    return this.args.acl
      .filter((entry) => entry.type === "group")
      .map((entry) => entry.id);
  }

  // TODO (martin) How are we going to deal with users that have the Owner permission
  // here if we don't want to expose that in the UI?
  get rows() {
    return this.args.acl.map((entry) => ({
      key: `${entry.type}-${entry.id}`,
      id: entry.id,
      permission: entry.permission,
      name: entry.full_name,
      type: entry.type,
    }));
  }

  @action
  startAdding() {
    this.addingGroup = true;
  }

  @action
  onGroupChosen(groupId) {
    if (groupId == null) {
      this.addingGroup = false;
      return;
    }

    const selectedGroup = this.args.groups.find(
      (group) => group.id === groupId
    );

    const newPermission = {
      id: selectedGroup.id,
      name: selectedGroup.name,
      full_name: selectedGroup.full_name,
      type: "group",
      // TODO (martin) Need to do this for more groups, like Everyone?
      permission:
        groupId === AUTO_GROUPS.anonymous_users.id
          ? "viewer"
          : DEFAULT_PERMISSION,
      metadata: {
        auto_group: selectedGroup.automatic,
      },
    };

    const next = [...this.args.acl, newPermission];

    this.args.onChange(next);
    this.addingGroup = false;
  }

  @action
  onPermissionChange(groupId, permission) {
    if (permission === REMOVE_ACTION.id) {
      this.args.onChange(
        this.args.acl.filter(
          (entry) => !(entry.type === "group" && entry.id === groupId)
        )
      );
      return;
    }

    const next = this.args.acl.map((entry) =>
      entry.type === "group" && entry.id === groupId
        ? { ...entry, permission }
        : entry
    );
    this.args.onChange(next);
  }
  // TODO (martin) How are we going to deal with users that have the Owner permission
  // here if we don't want to expose that in the UI?

  <template>
    <div class="d-access-control">
      {{#if this.rows.length}}
        <div class="d-access-control__rows">
          {{#each this.rows key="key" as |row|}}
            <div class="d-access-control__row" data-group-id={{row.groupId}}>
              <span class="d-access-control__group-name">{{row.name}}</span>
              <DropdownSelectBox
                class="d-access-control__permission"
                @value={{row.permission}}
                @content={{this.permissionOptions}}
                @onChange={{fn this.onPermissionChange row.id}}
                @options={{hash showCaret=true showFullTitle=true}}
              />
            </div>
          {{/each}}
        </div>
      {{/if}}

      {{#if this.addingGroup}}
        <ComboBox
          class="d-access-control__chooser"
          @value={{null}}
          @content={{this.availableGroups}}
          @onChange={{this.onGroupChosen}}
          @labelProperty="full_name"
          @options={{hash
            none="access_control.manage.add_group"
            expandedOnInsert=true
            filterable=true
          }}
        />
      {{else}}
        <DButton
          class="d-access-control__add btn-default"
          @icon="plus"
          @label="access_control.manage.add_group"
          @action={{this.startAdding}}
        />
      {{/if}}
    </div>
  </template>
}
