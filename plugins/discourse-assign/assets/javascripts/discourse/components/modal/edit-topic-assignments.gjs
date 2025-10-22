import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import TopicAssignments from "../topic-assignments";

export default class EditTopicAssignments extends Component {
  @service taskActions;

  @tracked assignments = this.topic.assignments();

  get title() {
    if (this.topic.isAssigned() || this.topic.hasAssignedPosts()) {
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
    this.args.closeModal();
    try {
      await this.#assign();
    } catch (error) {
      popupAjaxError(error);
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
    <DModal class="assign" @title={{this.title}} @closeModal={{@closeModal}}>
      <:body>
        <TopicAssignments
          @assignments={{this.assignments}}
          @onSubmit={{this.submit}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.submit}}
          @label={{if
            this.model.reassign
            "discourse_assign.reassign.title"
            "discourse_assign.assign_modal.assign"
          }}
        />

        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
