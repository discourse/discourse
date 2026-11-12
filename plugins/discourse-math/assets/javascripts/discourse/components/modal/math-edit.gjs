import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class MathEditModal extends Component {
  @tracked formApi;

  get initialData() {
    return {
      text: this.args.model?.initialText ?? "",
    };
  }

  @action
  onSubmit(data) {
    this.args.model?.onApply?.(data.text ?? "");
    this.args.closeModal();
  }

  @action
  onRegisterApi(api) {
    this.formApi = api;
  }

  @action
  submitForm() {
    this.formApi?.submit();
  }

  @action
  cancel() {
    this.args.closeModal();
  }

  <template>
    <DModal
      class="math-edit-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_math.edit_modal.title"}}
    >
      <:body>
        <Form
          @data={{this.initialData}}
          @onRegisterApi={{this.onRegisterApi}}
          @onSubmit={{this.onSubmit}}
          as |form|
        >
          <form.Field
            @format="full"
            @name="text"
            @title={{i18n "discourse_math.edit_modal.label"}}
            @type="textarea"
            as |field|
          >
            <field.Control
              autofocus={{true}}
              class="math-edit-modal__textarea"
            />
          </form.Field>
        </Form>
      </:body>
      <:footer>
        <DButton
          class="btn-primary math-edit-modal__apply"
          @action={{this.submitForm}}
          @label="discourse_math.edit_modal.apply"
        />
        <DButton class="btn-default" @action={{this.cancel}} @label="cancel" />
      </:footer>
    </DModal>
  </template>
}
