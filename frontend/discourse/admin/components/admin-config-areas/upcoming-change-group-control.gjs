import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import Group from "discourse/models/group";
import DButton from "discourse/ui-kit/d-button";
import DMultiSelect from "discourse/ui-kit/d-multi-select";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UpcomingChangeGroupControl extends Component {
  @tracked _saving = false;
  @tracked _draftGroups = null;

  get groups() {
    return this._draftGroups ?? this.args.groups;
  }

  get selection() {
    const lockedGroups = this.args.lockedGroups || [];
    return this.groups.map((name) => ({
      name,
      preventRemoval: lockedGroups.includes(name),
    }));
  }

  get dirty() {
    return (
      this.groups.length !== this.args.groups.length ||
      this.groups.some((group) => !this.args.groups.includes(group))
    );
  }

  get disabled() {
    return this._saving || this.args.disabled || this.args.locked;
  }

  get saveDisabled() {
    return (
      this.disabled ||
      !this.dirty ||
      (this.args.preventEmpty && !this.groups.length)
    );
  }

  get description() {
    if (!this.groups.length) {
      return (
        this.args.emptySelectionMessage ||
        i18n("admin.upcoming_changes.add_groups_to_enable")
      );
    }
    return this.args.description;
  }

  @action
  compareGroups(a, b) {
    return a.name === b.name;
  }

  @action
  groupsChanged(selection) {
    if (!this.disabled) {
      this._draftGroups = [
        ...new Set([
          ...(this.args.lockedGroups || []),
          ...selection.map((group) => group.name),
        ]),
      ];
    }
  }

  @action
  async loadGroups(term) {
    const groups = await Group.findAll({
      term,
      ignore_automatic: false,
      include_pseudogroups: true,
      include_everyone: this.args.includeEveryone,
    });
    return groups.filter(
      (group) =>
        (group.id !== 0 || this.args.includeEveryone) &&
        !this.args.disallowedGroups?.includes(group.id)
    );
  }

  @action
  async saveGroups() {
    if (this.saveDisabled) {
      return;
    }
    this._saving = true;
    try {
      if (await this.args.onSave(this.groups)) {
        this._draftGroups = null;
      }
    } finally {
      this._saving = false;
    }
  }

  <template>
    <div
      class={{dConcatClass
        "upcoming-change__group-selection-wrapper"
        (if @locked "--locked")
      }}
    >
      <div class="upcoming-change__group-controls">
        <DMultiSelect
          class="upcoming-change__group-selector"
          @compareFn={{this.compareGroups}}
          @disabled={{this.disabled}}
          @label={{i18n "admin.upcoming_changes.select_groups"}}
          @loadFn={{this.loadGroups}}
          @matchTriggerWidth={{true}}
          @onChange={{this.groupsChanged}}
          @placement="bottom-start"
          @selection={{this.selection}}
        >
          <:selection as |group|>
            {{group.name}}
            {{#if group.preventRemoval}}
              {{dIcon "lock"}}
            {{/if}}
          </:selection>
          <:result as |group|>{{group.name}}</:result>
        </DMultiSelect>
        {{#unless @locked}}
          <DButton
            class={{dConcatClass
              "upcoming-change__save-groups"
              (if this.saveDisabled "btn-default" "btn-success")
            }}
            @disabled={{this.saveDisabled}}
            @icon="check"
            @title="admin.upcoming_changes.save_groups"
            {{on "click" this.saveGroups}}
          />
        {{/unless}}
      </div>
      {{#if this.description}}
        <p class="upcoming-change__groups-description">{{this.description}}</p>
      {{/if}}
    </div>
  </template>
}
