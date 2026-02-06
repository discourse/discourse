import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AiSecretCreateModal extends Component {
  @tracked isSaving = false;

  @cached
  get formData() {
    return {
      name: "",
      secret: "",
    };
  }

  @action
  async save(data) {
    this.isSaving = true;

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
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_ai.secrets.modal.title"}}
      @closeModal={{@closeModal}}
      class="ai-secret-create-modal"
    >
      <:body>
        <Form @onSubmit={{this.save}} @data={{this.formData}} as |form|>
          <form.Field
            @name="name"
            @title={{i18n "discourse_ai.secrets.name"}}
            @validation="required|length:1,100"
            @format="large"
            as |field|
          >
            <field.Input />
          </form.Field>

          <form.Field
            @name="secret"
            @title={{i18n "discourse_ai.secrets.secret"}}
            @validation="required"
            @format="large"
            as |field|
          >
            <field.Password autocomplete="off" />
          </form.Field>

          <form.Submit @label="discourse_ai.secrets.save" class="btn-primary" />
        </Form>
      </:body>
    </DModal>
  </template>
}
