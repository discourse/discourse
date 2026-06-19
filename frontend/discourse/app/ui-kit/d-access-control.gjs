import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { AUTO_GROUPS } from "discourse/lib/constants";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DSelect from "discourse/ui-kit/d-select";
import { i18n } from "discourse-i18n";

// const SPECIAL_GROUP_IDS = new Set([
//   AUTO_GROUPS.anonymous_users.id,
//   AUTO_GROUPS.logged_in_users.id,
// ]);

const DEFAULT_LEVEL = "editor";
const LEVELS = [
  { id: "editor", name: i18n("access_control.manage.access_level_editor") },
  { id: "viewer", name: i18n("access_control.manage.access_level_viewer") },
];
const REMOVE_ACTION = {
  id: "remove",
  name: i18n("access_control.manage.access_level_remove"),
};

export default class DAccessControl extends Component {
  @tracked addingGroup = false;

  get levelOptions() {
    if (this.args.transformLevelOptions) {
      return [...this.args.transformLevelOptions(LEVELS), REMOVE_ACTION];
    }
    return [...LEVELS, REMOVE_ACTION];
  }

  get availableGroups() {
    const taken = new Set(this.selectedGroupIds);
    // const special = [
    //   {
    //     id: AUTO_GROUPS.anonymous_users.id,
    //     name: i18n("access_control.manage.access_anonymous"),
    //   },
    //   {
    //     id: AUTO_GROUPS.logged_in_users.id,
    //     name: i18n("access_control.manage.access_members"),
    //   },
    // ];

    // return [
    //   ...special,
    //   ...(this.args.groups || []).filter(
    //     (group) => !SPECIAL_GROUP_IDS.has(group.id)
    //   ),
    // ].filter((group) => !taken.has(group.id));
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
      // name: this.#nameFor(entry.group_id),
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
        groupId === AUTO_GROUPS.anonymous_users.id ? "viewer" : DEFAULT_LEVEL,
      metadata: {
        auto_group: selectedGroup.automatic,
      },
    };

    const next = [...this.args.acl, newPermission];

    this.args.onChange(next);
    this.addingGroup = false;
  }

  @action
  onLevelChange(groupId, level) {
    if (level === REMOVE_ACTION.id) {
      this.args.onChange(
        this.args.acl.filter(
          (entry) => !(entry.type === "group" && entry.id === groupId)
        )
      );
      return;
    }

    const next = this.args.acl.map((entry) =>
      entry.type === "group" && entry.id === groupId
        ? { ...entry, permission: level }
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
              <DSelect
                class="d-access-control__level"
                @value={{row.permission}}
                @includeNone={{false}}
                @onChange={{fn this.onLevelChange row.id}}
                as |dropdown|
              >
                {{#each this.levelOptions as |option|}}
                  <dropdown.Option
                    @value={{option.id}}
                    class="d-access-control__level-{{option.id}}"
                  >
                    {{option.name}}
                  </dropdown.Option>
                {{/each}}
              </DSelect>
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
