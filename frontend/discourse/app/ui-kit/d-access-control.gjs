import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DSelect from "discourse/ui-kit/d-select";
import { i18n } from "discourse-i18n";

// The anonymous (4) and trust_level_0 (10) auto-groups let a board be made
// public or member-visible. anonymous is not present in site.groups nor in the
// JS AUTO_GROUPS constant, so it is defined explicitly here.
const ANONYMOUS_GROUP_ID = 4;
const TRUST_LEVEL_0_GROUP_ID = 10;
const SPECIAL_GROUP_IDS = new Set([ANONYMOUS_GROUP_ID, TRUST_LEVEL_0_GROUP_ID]);

const DEFAULT_LEVEL = "editor";
const LEVELS = ["editor", "viewer"];
const REMOVE_ACTION = "remove";

export default class DAccessControl extends Component {
  @service site;

  @tracked addingGroup = false;

  get value() {
    return this.args.value || [];
  }

  get levelOptions() {
    return [
      ...LEVELS.map((level) => ({
        id: level,
        name: this.#levelLabel(level),
      })),
      {
        id: REMOVE_ACTION,
        name: i18n("access_control.manage.access_level_remove"),
      },
    ];
  }

  get availableGroups() {
    const taken = new Set(this.selectedGroupIds);
    const special = [
      {
        id: ANONYMOUS_GROUP_ID,
        name: i18n("access_control.manage.access_anonymous"),
      },
      {
        id: TRUST_LEVEL_0_GROUP_ID,
        name: i18n("access_control.manage.access_members"),
      },
    ];

    return [
      ...special,
      ...(this.args.groups || []).filter((g) => !SPECIAL_GROUP_IDS.has(g.id)),
    ].filter((g) => !taken.has(g.id));
  }

  get selectedGroupIds() {
    return this.value.map((entry) => entry.group_id);
  }

  get rows() {
    return this.value.map((entry) => ({
      groupId: entry.group_id,
      level: entry.level,
      name: this.#nameFor(entry.group_id),
    }));
  }

  #levelLabel(level) {
    return i18n(`access_control.manage.access_level_${level}`);
  }

  #nameFor(groupId) {
    if (groupId === ANONYMOUS_GROUP_ID) {
      return i18n("access_control.manage.access_anonymous");
    }
    if (groupId === TRUST_LEVEL_0_GROUP_ID) {
      return i18n("access_control.manage.access_members");
    }
    return this.site.groupsById[groupId]?.name ?? `#${groupId}`;
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

    const next = [
      ...this.value,
      {
        group_id: groupId,
        level: groupId === ANONYMOUS_GROUP_ID ? "viewer" : DEFAULT_LEVEL,
      },
    ];

    this.args.onChange(next);
    this.addingGroup = false;
  }

  @action
  onLevelChange(groupId, level) {
    if (level === REMOVE_ACTION) {
      this.args.onChange(
        this.value.filter((entry) => entry.group_id !== groupId)
      );
      return;
    }

    const next = this.value.map((entry) =>
      entry.group_id === groupId ? { group_id: entry.group_id, level } : entry
    );
    this.args.onChange(next);
  }

  <template>
    <div class="d-access-control">
      {{#if this.rows.length}}
        <div class="d-access-control__rows">
          {{#each this.rows key="groupId" as |row|}}
            <div class="d-access-control__row" data-group-id={{row.groupId}}>
              <span class="d-access-control__group-name">{{row.name}}</span>
              <DSelect
                class="d-access-control__level"
                @value={{row.level}}
                @includeNone={{false}}
                @onChange={{fn this.onLevelChange row.groupId}}
                as |s|
              >
                {{#each this.levelOptions as |option|}}
                  <s.Option
                    @value={{option.id}}
                    class="d-access-control__level-{{option.id}}"
                  >{{option.name}}</s.Option>
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
