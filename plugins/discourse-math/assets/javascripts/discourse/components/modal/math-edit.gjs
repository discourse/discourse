import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
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
      @title={{i18n "discourse_math.edit_modal.title"}}
      @closeModal={{@closeModal}}
      class="math-edit-modal"
    >
      <:body>
        <Form
          @data={{this.initialData}}
          @onSubmit={{this.onSubmit}}
          @onRegisterApi={{this.onRegisterApi}}
          as |form|
        >
          <form.Field
            @name="text"
            @title={{i18n "discourse_math.edit_modal.label"}}
            @format="full"
            as |field|
          >
            <field.Textarea
              class="math-edit-modal__textarea"
              autofocus={{true}}
            />
          </form.Field>
        </Form>
      </:body>
      <:footer>
        <DButton
          @action={{this.submitForm}}
          @label="discourse_math.edit_modal.apply"
          class="btn-primary math-edit-modal__apply"
        />
        <DButton @action={{this.cancel}} @label="cancel" class="btn-default" />
      </:footer>
    </DModal>
  </template>
}
