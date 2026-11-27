import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";
import Assignment from "./assignment.gjs";

export default class TopicAssignments extends Component {
  @service taskActions;
  @service siteSettings;

  @tracked selectedAssignment = this.args.assignments?.find((a) => a.id === 0);
  #formApi;

  get statusOptions() {
    return this.siteSettings.assign_statuses
      .split("|")
      .filter(Boolean)
      .map((status) => ({ id: status, name: status }));
  }

  get searchUrl() {
    return this.taskActions.searchUrlFor(this.args.topicId);
  }

  get suggestions() {
    return this.taskActions.suggestionsFor(this.args.topicId);
  }

  get assignmentOptions() {
    return this.args.assignments.map((a) => this.#toComboBoxOption(a));
  }

  @action
  registerApi(api) {
    this.#formApi = api;
    this.args.formApi.submit = api.submit;
  }

  @action
  addAssignee([name], [item]) {
    if (!name) {
      return;
    }
    const assignments = this.#formApi.get("assignments");
    const group = item?.isGroup;
    let error;
    if (
      assignments.some((assignment) =>
        group ? assignment.group_name === name : assignment.username === name
      )
    ) {
      error = i18n("discourse_assign.duplicate_assignee");
    } else if (
      group &&
      assignments.some((assignment) => assignment.group_name)
    ) {
      error = i18n("discourse_assign.one_group_only");
    } else if (
      assignments.length + this.args.collectionData.active_post_assignments >=
      this.args.collectionData.max_assignments
    ) {
      error = i18n("discourse_assign.assignment_limit", {
        limit: this.args.collectionData.max_assignments,
      });
    } else if (
      !this.args.collectionData.can_add_multiple &&
      assignments.length
    ) {
      return;
    }
    if (error) {
      this.#formApi.addError("assignee", {
        title: i18n("discourse_assign.assign_modal.assignee_label"),
        message: error,
      });
      return;
    }
    this.#formApi.removeError("assignee");
    this.#formApi.set("assignments", [
      ...assignments,
      {
        username: group ? null : name,
        group_name: group ? name : null,
        avatar_template: item?.avatar_template,
        note: "",
        status: this.statusOptions[0]?.id,
        showNote: false,
      },
    ]);
  }

  @action
  addNote(index) {
    this.#formApi.set(`assignments.${index}.showNote`, true);
  }

  @action
  deleteNote(index, event) {
    const textarea = event.target
      .closest(".topic-assignments-editor__note")
      .querySelector("textarea");
    this.#formApi.set(`assignments.${index}.note`, "");
    textarea.focus();
  }

  @action
  selectAssignment(id) {
    this.selectedAssignment = this.args.assignments.find((a) => a.id === id);
  }

  #toComboBoxOption(assignment) {
    const option = { id: assignment.id };
    if (assignment.targetType === "Topic") {
      option.name = i18n("edit_assignments_modal.topic");
    } else {
      option.name = `${i18n("edit_assignments_modal.post")} #${
        assignment.postNumber
      }`;
    }
    return option;
  }

  <template>
    {{#if @collectionData}}
      <Form
        class="topic-assignments-editor"
        @data={{@collectionData}}
        @onRegisterApi={{this.registerApi}}
        @onSubmit={{@onSubmit}}
        as |form data|
      >
        <form.Collection @name="assignments" as |collection index assignment|>
          <div class="topic-assignments-editor__row">
            <div class="topic-assignments-editor__person">
              {{#if assignment.username}}
                {{dAvatar assignment imageSize="small"}}
                <span
                  class="topic-assignments-editor__name"
                >{{assignment.username}}</span>
              {{else}}
                {{dIcon "group-plus"}}
                <span
                  class="topic-assignments-editor__name"
                >{{assignment.group_name}}</span>
              {{/if}}
              {{#unless assignment.showNote}}
                <DButton
                  class="btn-transparent"
                  @action={{fn this.addNote index}}
                  @icon="far-note-sticky"
                  @translatedTitle={{i18n
                    "discourse_assign.add_note"
                    username=(or assignment.username assignment.group_name)
                  }}
                />
              {{/unless}}
              <DButton
                class="btn-transparent topic-assignments-editor__remove"
                @action={{fn collection.remove index}}
                @icon={{if assignment.username "user-xmark" "group-times"}}
                @translatedTitle={{i18n
                  "discourse_assign.remove_assignee"
                  username=(or assignment.username assignment.group_name)
                }}
              />
            </div>
            {{#if this.siteSettings.enable_assign_status}}
              <collection.Field
                @name="status"
                @title={{i18n "discourse_assign.assign_modal.status_label"}}
                @type="select"
                as |field|
              >
                <field.Control @includeNone={{false}} as |select|>
                  {{#each this.statusOptions as |status|}}
                    <select.Option
                      @value={{status.id}}
                    >{{status.name}}</select.Option>
                  {{/each}}
                </field.Control>
              </collection.Field>
            {{/if}}
            {{#if assignment.showNote}}
              <div class="topic-assignments-editor__note">
                <collection.Field
                  @format="full"
                  @name="note"
                  @showOptional={{false}}
                  @showTitle={{false}}
                  @title={{i18n "discourse_assign.assign_modal.note_label"}}
                  @type="textarea"
                  as |field|
                >
                  <field.Control
                    aria-label={{i18n
                      "discourse_assign.note_for"
                      username=(or assignment.username assignment.group_name)
                    }}
                    placeholder={{i18n "discourse_assign.note_placeholder"}}
                    rows="1"
                    @autoResize={{true}}
                    {{(unless assignment.note dAutoFocus)}}
                  />
                </collection.Field>
                {{#if assignment.note}}
                  <DButton
                    class="btn-small btn-transparent topic-assignments-editor__note-delete"
                    @action={{this.deleteNote}}
                    @actionParam={{index}}
                    @forwardEvent={{true}}
                    @icon="xmark"
                    @translatedTitle={{i18n
                      "discourse_assign.delete_note"
                      username=(or assignment.username assignment.group_name)
                    }}
                  />
                {{/if}}
              </div>
            {{/if}}
          </div>
        </form.Collection>
        {{#if
          (or @collectionData.can_add_multiple (not data.assignments.length))
        }}
          <form.Field
            @format="full"
            @name="assignee"
            @showOptional={{false}}
            @title={{i18n "discourse_assign.add_assignee"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <EmailGroupUserChooser
                @id={{field.id}}
                @onChange={{this.addAssignee}}
                @options={{hash
                  mobilePlacementStrategy="absolute"
                  maximum=1
                  searchUrl=this.searchUrl
                  customSearchOptions=(hash
                    defaultSearchResults=this.suggestions
                  )
                  expandedOnInsert=(not data.assignments.length)
                  caretUpIcon="magnifying-glass"
                  caretDownIcon="magnifying-glass"
                }}
                @showUserStatus={{true}}
                @value={{null}}
              />
            </field.Control>
          </form.Field>
        {{/if}}
      </Form>
    {{else}}
      <div class="control-group target">
        <label>{{i18n "discourse_assign.assign_modal.assignment_label"}}</label>
        <ComboBox
          @content={{this.assignmentOptions}}
          @onChange={{this.selectAssignment}}
          @value={{this.selectedAssignment.id}}
        />
      </div>
      <Assignment
        @assignment={{this.selectedAssignment}}
        @onSubmit={{@onSubmit}}
        @showValidationErrors={{false}}
      />
    {{/if}}
  </template>
}
