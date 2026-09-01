import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class AiSecretCreateModal extends Component {
  @cached
  get formData() {
    return {
      name: "",
      secret: "",
    };
  }

  @action
  async save(data) {
    try {
      const result = await ajax("/admin/plugins/discourse-ai/ai-secrets", {
        type: "POST",
        data: { ai_secret: data },
      });

      const secret = result.ai_secret;

      if (this.args.model.onSave) {
        this.args.model.onSave(secret);
      }

      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      class="ai-secret-create-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_ai.secrets.modal.title"}}
    >
      <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
        <form.Field
          @format="large"
          @name="name"
          @title={{i18n "discourse_ai.secrets.name"}}
          @type="input"
          @validation="required|length:1,100"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @format="large"
          @name="secret"
          @title={{i18n "discourse_ai.secrets.secret"}}
          @type="password"
          @validation="required"
          as |field|
        >
          <field.Control autocomplete="off" />
        </form.Field>

        <form.Actions>
          <form.Submit @label="discourse_ai.secrets.save" />
        </form.Actions>
      </Form>
    </DModal>
  </template>
}
