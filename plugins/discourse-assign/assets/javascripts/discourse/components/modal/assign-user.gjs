import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { i18n } from "discourse-i18n";
import AssignUserForm from "../assign-user-form";

export default class AssignUser extends Component {
  @service taskActions;

  model = new TrackedObject(this.args.model);

  // `submit` property will be mutated by the `AssignUserForm` component
  formApi = {
    submit() {},
  };

  get title() {
    let i18nSuffix;

    switch (this.model.targetType) {
      case "Post":
        i18nSuffix = "_post_modal";
        break;
      case "Topic":
        i18nSuffix = "_modal";
        break;
    }

    return i18n(
      `discourse_assign.assign${i18nSuffix}.${
        this.model.reassign ? "reassign_title" : "title"
      }`
    );
  }

  @action
  async onSubmit() {
    this.args.closeModal();
    await this.taskActions.assign(this.model);
  }

  <template>
    <DModal class="assign" @title={{this.title}} @closeModal={{@closeModal}}>
      <:body>
        <AssignUserForm
          @model={{this.model}}
          @onSubmit={{this.onSubmit}}
          @formApi={{this.formApi}}
        />
      </:body>

      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.formApi.submit}}
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
