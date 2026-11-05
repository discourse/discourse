import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";
import TopicAssignments from "../topic-assignments.gjs";

export default class EditTopicAssignments extends Component {
  @service taskActions;
  @service siteSettings;

  @tracked editor;
  @tracked saving = false;

  assignments = this.topic.assignments?.() || [];
  formApi = { submit: () => {} };

  constructor() {
    super(...arguments);
    if (this.useCollection) {
      this.#loadAssignments();
    }
  }

  get useCollection() {
    return (
      this.siteSettings.assign_allow_multiple_topic_assignees ||
      this.topic.topic_assignments?.length > 1
    );
  }

  get title() {
    if (
      this.topic.isAssigned?.() ||
      this.topic.hasAssignedPosts?.() ||
      this.topic.topic_assignments?.length
    ) {
      return i18n("edit_assignments_modal.title");
    } else {
      return i18n("discourse_assign.assign_modal.title");
    }
  }

  get topic() {
    return this.args.model.topic;
  }

  @action
  async submit() {
    if (this.useCollection) {
      return this.formApi.submit();
    }
    try {
      await this.#assign();
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async saveCollection(data) {
    this.saving = true;
    try {
      await this.taskActions.replaceTopicAssignments(
        this.topic,
        data.assignments,
        this.editor.version
      );
      this.args.model.onSuccess?.();
      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  async #loadAssignments() {
    try {
      const editor = await this.taskActions.refreshTopicAssignments(this.topic);
      if (!this.isDestroying) {
        this.editor = {
          ...editor,
          assignments: editor.topic_assignments.map((assignment) => ({
            id: assignment.id,
            username:
              assignment.assigned_to_type === "User"
                ? assignment.assigned_to.username
                : null,
            group_name:
              assignment.assigned_to_type === "Group"
                ? assignment.assigned_to.name
                : null,
            avatar_template: assignment.assigned_to.avatar_template,
            note: assignment.note || "",
            status: assignment.status,
            showNote: false,
          })),
        };
      }
    } catch (error) {
      popupAjaxError(error);
      this.args.closeModal();
    }
  }

  async #assign() {
    for (const assignment of this.assignments) {
      if (assignment.isEdited) {
        await this.taskActions.putAssignment(assignment);
      }
    }
  }

  <template>
    <DModal class="assign" @closeModal={{@closeModal}} @title={{this.title}}>
      <:body>
        {{#if this.useCollection}}
          {{#if this.editor}}
            <TopicAssignments
              @collectionData={{this.editor}}
              @formApi={{this.formApi}}
              @onSubmit={{this.saveCollection}}
              @topicId={{this.topic.id}}
            />
          {{else}}
            <DConditionalLoadingSpinner @condition={{true}} />
          {{/if}}
        {{else}}
          <TopicAssignments
            @assignments={{this.assignments}}
            @onSubmit={{this.submit}}
          />
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.submit}}
          @disabled={{or
            this.saving
            (and this.useCollection (not this.editor))
          }}
          @label={{if
            this.useCollection
            "discourse_assign.save_assignments"
            "discourse_assign.assign_modal.assign"
          }}
        />

        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
