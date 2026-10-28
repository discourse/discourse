import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class UpcomingChangeGroupControl extends Component {
  @tracked _saving = false;
  @tracked _draftGroups = null;

  get groups() {
    return this._draftGroups ?? this.args.groups;
  }

  get dirty() {
    return (
      this.groups.length !== this.args.groups.length ||
      this.groups.some((group) => !this.args.groups.includes(group))
    );
  }

  get disabled() {
    return this._saving || this.args.disabled;
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
  groupsChanged(groups) {
    if (!this.disabled) {
      this._draftGroups = [
        ...new Set([...(this.args.lockedGroups || []), ...groups]),
      ];
    }
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
      class="upcoming-change__group-selection-wrapper"
      hidden={{not @expanded}}
      id={{@id}}
    >
      <div class="upcoming-change__group-controls">
        <EmailGroupUserChooser
          @onChange={{this.groupsChanged}}
          @options={{hash
            disabled=this.disabled
            groupsOnly=true
            useHeaderFilter=true
            fullWidthWrap=true
            lockedValues=@lockedGroups
            excludedGroupIds=@disallowedGroups
            includeEveryone=@includeEveryone
            none="admin.upcoming_changes.select_groups"
            headerAriaLabel=(i18n "admin.upcoming_changes.select_groups")
          }}
          @value={{this.groups}}
        />
        <DButton
          class="btn-primary upcoming-change__save-groups"
          @disabled={{this.saveDisabled}}
          @icon="check"
          @title="admin.upcoming_changes.save_groups"
          {{on "click" this.saveGroups}}
        />
      </div>
      {{#if this.description}}
        <p class="upcoming-change__groups-description">{{this.description}}</p>
      {{/if}}
    </div>
  </template>
}
