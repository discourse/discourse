import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";

export default class MathInsertModal extends Component {
  @tracked formApi;
  @tracked isBlock;

  constructor() {
    super(...arguments);
    this.isBlock = this.args.model?.isBlock ?? false;
  }

  get initialData() {
    return {
      text: "",
    };
  }

  get modalTitle() {
    return this.isBlock
      ? i18n("discourse_math.insert_modal.title_block")
      : i18n("discourse_math.insert_modal.title_inline");
  }

  @action
  onSubmit(data) {
    const text = data.text?.trim() ?? "";
    if (text) {
      this.args.model?.onInsert?.(text, this.isBlock);
    }
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

  @action
  toggleBlockMode() {
    this.isBlock = !this.isBlock;
  }

  <template>
    <DModal
      @title={{this.modalTitle}}
      @closeModal={{@closeModal}}
      class="math-insert-modal"
    >
      <:body>
        <div class="math-insert-modal__toggle">
          <DToggleSwitch
            @state={{this.isBlock}}
            @label="discourse_math.insert_modal.block_mode"
            {{on "click" this.toggleBlockMode}}
          />
        </div>
        <Form
          @data={{this.initialData}}
          @onSubmit={{this.onSubmit}}
          @onRegisterApi={{this.onRegisterApi}}
          as |form|
        >
          <form.Field
            @name="text"
            @title={{i18n "discourse_math.insert_modal.label"}}
            @format="full"
            @validation="required"
            as |field|
          >
            <field.Textarea
              class="math-insert-modal__textarea"
              placeholder={{i18n "discourse_math.insert_modal.placeholder"}}
              autofocus={{true}}
            />
          </form.Field>
        </Form>
      </:body>
      <:footer>
        <DButton
          @action={{this.submitForm}}
          @label="discourse_math.insert_modal.insert"
          class="btn-primary math-insert-modal__insert"
        />
        <DButton @action={{this.cancel}} @label="cancel" class="btn-default" />
      </:footer>
    </DModal>
  </template>
}
