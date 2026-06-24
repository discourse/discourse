import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { AUTO_GROUPS } from "discourse/lib/constants";
import ComboBox from "discourse/select-kit/components/combo-box";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const EDIT_PERMISSION = "edit";
const READ_ONLY_PERMISSION = "view";
const READ_ONLY_DEFAULT_AUTO_GROUPS = [
  AUTO_GROUPS.anonymous_users.id,
  AUTO_GROUPS.everyone.id,
  AUTO_GROUPS.trust_level_0.id,
];
const REMOVE_ACTION = {
  id: "remove",
  name: i18n("access_control.manage.access_permission_remove"),
  description: i18n(
    "access_control.manage.access_permission_remove_description"
  ),
};

function defaultPermissions() {
  return [
    {
      id: READ_ONLY_PERMISSION,
      level: 1,
      name: i18n("access_control.manage.access_permission_viewer"),
      description: i18n(
        "access_control.manage.access_permission_viewer_description"
      ),
    },
    {
      id: EDIT_PERMISSION,
      level: 2,
      name: i18n("access_control.manage.access_permission_editor"),
      description: i18n(
        "access_control.manage.access_permission_editor_description"
      ),
    },
  ];
}

export default class DAccessControl extends Component {
  @tracked addingGroup = false;

  constructor() {
    super(...arguments);
    this.permissionOptions = this.buildPermissionOptions();
  }

  /**
   * If a transformPermissionOptions function is provided, it is passed all
   * default permissions and can change the name, description, or level of
   * these options, OR add new options, returning the new array.
   *
   * The level property is used to sort the options, and is an indicator
   * of the level of access the permission provides, since e.g. Edit is a
   * higher level of access than View, and to Edit by definition you need
   * to be able to View.
   *
   * Otherwise, the default permissions are used.
   */
  buildPermissionOptions() {
    const permissions =
      this.args.transformPermissionOptions?.(defaultPermissions()) ||
      defaultPermissions();

    return [
      ...permissions.sort((a, b) => a.level - b.level),
      {
        ...REMOVE_ACTION,
        classNames:
          "d-access-control__permission-divider d-access-control__permission-remove",
      },
    ];
  }

  get availableGroups() {
    const taken = new Set(this.selectedGroupIds);
    return this.args.groups
      .filter((group) => !taken.has(group.id))
      .sort((a, b) => {
        if (a.automatic !== b.automatic) {
          return a.automatic ? -1 : 1;
        }

        return (a.full_name || a.name).localeCompare(b.full_name || b.name);
      });
  }

  get selectedGroupIds() {
    return this.args.acl
      .filter((entry) => entry.type === "group")
      .map((entry) => entry.id);
  }

  // TODO (martin) How are we going to deal with users that have the Owner permission
  // here if we don't want to expose that in the UI?
  get rows() {
    return this.args.acl
      .map((entry) => ({
        key: `${entry.type}-${entry.id}`,
        id: entry.id,
        permission: entry.permission,
        name: entry.full_name,
        type: entry.type,
        mandatory: entry.mandatory,
      }))
      .sort((a, b) => {
        if (a.mandatory !== b.mandatory) {
          return a.mandatory ? -1 : 1;
        }

        return a.name.localeCompare(b.name);
      });
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
      permission: READ_ONLY_DEFAULT_AUTO_GROUPS.includes(selectedGroup.id)
        ? READ_ONLY_PERMISSION
        : EDIT_PERMISSION,
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
            <div
              class={{dConcatClass
                "d-access-control__row"
                (if row.mandatory "--mandatory")
              }}
              data-group-id={{row.groupId}}
            >
              <span class="d-access-control__group-name">{{#if row.mandatory}}
                  <DTooltip
                    @content={{i18n
                      "access_control.manage.mandatory_acl_tooltip"
                    }}
                  >
                    <:trigger>
                      {{dIcon "lock"}}
                    </:trigger>
                  </DTooltip>
                {{/if}}
                {{row.name}}</span>
              <DropdownSelectBox
                class="d-access-control__permission"
                @value={{row.permission}}
                @content={{this.permissionOptions}}
                @onChange={{fn this.onPermissionChange row.id}}
                @options={{hash
                  showCaret=true
                  showFullTitle=true
                  disabled=row.mandatory
                }}
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
