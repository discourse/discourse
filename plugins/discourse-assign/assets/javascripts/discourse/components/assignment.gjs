import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { TextArea } from "@ember/legacy-built-in-components";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import AssigneeChooser from "./assignee-chooser";

export default class Assignment extends Component {
  @service siteSettings;
  @service taskActions;

  get assignee() {
    return this.args.assignment.username || this.args.assignment.group_name;
  }

  get status() {
    return this.args.assignment.status || this.assignStatuses[0];
  }

  get assignStatuses() {
    return this.siteSettings.assign_statuses.split("|").filter(Boolean);
  }

  get assignStatusOptions() {
    return this.assignStatuses.map((status) => ({ id: status, name: status }));
  }

  get assigneeIsEmpty() {
    return !this.args.assignment.username && !this.args.assignment.group_name;
  }

  get showAssigneeIeEmptyError() {
    return this.assigneeIsEmpty && this.args.showValidationErrors;
  }

  @action
  handleTextAreaKeydown(event) {
    if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
      this.args.onSubmit();
    }
  }

  @action
  markAsEdited() {
    this.args.assignment.isEdited = true;
  }

  @action
  setAssignee([newAssignee]) {
    if (this.taskActions.allowedGroupsForAssignment.includes(newAssignee)) {
      this.args.assignment.username = null;
      this.args.assignment.group_name = newAssignee;
    } else {
      this.args.assignment.username = newAssignee;
      this.args.assignment.group_name = null;
    }
    this.markAsEdited();
  }

  @action
  setStatus(status) {
    this.args.assignment.status = status;
    this.markAsEdited();
  }

  <template>
    <div
      class="control-group
        {{if this.showAssigneeIeEmptyError 'assignee-error'}}"
    >
      <label>{{i18n "discourse_assign.assign_modal.assignee_label"}}</label>
      <AssigneeChooser
        autocomplete="off"
        @id="assignee-chooser"
        @value={{this.assignee}}
        @onChange={{this.setAssignee}}
        @showUserStatus={{true}}
        @options={{hash
          mobilePlacementStrategy="absolute"
          includeGroups=true
          customSearchOptions=(hash
            assignableGroups=true
            defaultSearchResults=this.taskActions.suggestions
          )
          groupMembersOf=this.taskActions.allowedGroups
          maximum=1
          tabindex=1
          expandedOnInsert=(not this.assignee)
          caretUpIcon="magnifying-glass"
          caretDownIcon="magnifying-glass"
        }}
      />

      {{#if this.showAssigneeIeEmptyError}}
        <span class="error-label">
          {{icon "triangle-exclamation"}}
          {{i18n "discourse_assign.assign_modal.choose_assignee"}}
        </span>
      {{/if}}
    </div>

    {{#if this.siteSettings.enable_assign_status}}
      <div class="control-group assign-status">
        <label>{{i18n "discourse_assign.assign_modal.status_label"}}</label>
        <ComboBox
          @id="assign-status"
          @content={{this.assignStatusOptions}}
          @value={{this.status}}
          @onChange={{this.setStatus}}
        />
      </div>
    {{/if}}

    <div class="control-group assign-status">
      <label>
        {{i18n "discourse_assign.assign_modal.note_label"}}&nbsp;<span
          class="label-optional"
        >{{i18n "discourse_assign.assign_modal.optional_label"}}</span>
      </label>

      <TextArea
        id="assign-modal-note"
        @value={{@assignment.note}}
        {{on "keydown" this.handleTextAreaKeydown}}
        {{on "input" this.markAsEdited}}
      />
    </div>
  </template>
}
