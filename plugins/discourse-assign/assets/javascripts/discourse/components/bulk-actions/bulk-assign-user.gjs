import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import AssignUserForm from "discourse/plugins/discourse-assign/discourse/components/assign-user-form";
import assignmentPayload from "discourse/plugins/discourse-assign/discourse/lib/assignment-payload";

export default class BulkActionsAssignUser extends Component {
  model = trackedObject({});

  formApi = {
    submit() {},
  };

  @action
  async submit() {
    return await this.args.onPerform({
      type: "assign",
      ...assignmentPayload(this.model),
    });
  }

  @action
  performRegistration() {
    this.args.onRegisterAction?.(() => this.formApi.submit());
  }

  <template>
    <span {{didInsert this.performRegistration}}></span>
    <AssignUserForm
      @model={{this.model}}
      @onSubmit={{this.submit}}
      @formApi={{this.formApi}}
    />
  </template>
}
