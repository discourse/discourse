import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { extractError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

// Asks for a name: renaming something, or naming something new.
export default class RenameModal extends Component {
  @tracked flash;

  formData = { name: this.args.model.value };

  @action
  async save({ name }) {
    try {
      await this.args.model.save(name.trim());
      this.args.closeModal();
    } catch (error) {
      this.flash = extractError(error);
    }
  }

  <template>
    <DModal
      class="concord-rename-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @title={{@model.title}}
    >
      <:body>
        <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
          <form.Field
            @format="full"
            @name="name"
            @title={{i18n (themePrefix "channel_menu.name")}}
            @type="input"
            @validation="required|length:1,100"
            as |field|
          >
            <field.Control />
          </form.Field>

          <form.Actions>
            <form.Submit
              @label={{unless @model.submitLabel "save"}}
              @translatedLabel={{@model.submitLabel}}
            />
            <form.Button
              class="btn-transparent"
              @action={{@closeModal}}
              @label="cancel"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
