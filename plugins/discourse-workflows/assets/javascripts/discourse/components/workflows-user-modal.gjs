import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

const STYLE_CLASSES = {
  primary: "btn-primary",
  danger: "btn-danger",
  default: "btn-default",
};

export default class WorkflowsUserModal extends Component {
  @tracked submitting = false;

  get buttons() {
    return (this.args.model.buttons || []).map((button) => ({
      ...button,
      styleClass: STYLE_CLASSES[button.style] || STYLE_CLASSES.default,
    }));
  }

  @action
  async respond(button) {
    if (this.submitting) {
      return;
    }

    this.submitting = true;

    try {
      await ajax("/discourse-workflows/modal-responses", {
        type: "POST",
        data: { action_id: button.action_id },
      });
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
      this.submitting = false;
    }
  }

  <template>
    <DModal
      @title={{@model.title}}
      @closeModal={{@closeModal}}
      class="workflows-user-modal"
    >
      <:body>
        {{#if @model.body}}
          <p class="workflows-user-modal__body">{{@model.body}}</p>
        {{/if}}
      </:body>
      <:footer>
        {{#each this.buttons as |button|}}
          <DButton
            class={{button.styleClass}}
            @translatedLabel={{button.label}}
            @action={{fn this.respond button}}
            @disabled={{this.submitting}}
          />
        {{/each}}
      </:footer>
    </DModal>
  </template>
}
