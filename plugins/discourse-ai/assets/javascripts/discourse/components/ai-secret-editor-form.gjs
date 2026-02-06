import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { later } from "@ember/runloop";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { i18n } from "discourse-i18n";

export default class AiSecretEditorForm extends Component {
  @service toasts;
  @service router;
  @service dialog;

  @tracked isSaving = false;

  @cached
  get formData() {
    const { model } = this.args;

    return {
      name: model.name,
      secret: model.secret,
    };
  }

  @action
  async save(data) {
    this.isSaving = true;
    const isNew = this.args.model.isNew;

    try {
      const dataToSave = { ...data };
      await this.args.model.save(dataToSave);

      if (isNew) {
        addUniqueValueToArray(this.args.secrets.content, this.args.model);
        this.router.transitionTo(
          "adminPlugins.show.discourse-ai-secrets.index"
        );
      }
      this.toasts.success({
        data: { message: i18n("discourse_ai.secrets.saved") },
        duration: "short",
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      later(() => {
        this.isSaving = false;
      }, 1000);
    }
  }

  @action
  delete() {
    return this.dialog.confirm({
      message: i18n("discourse_ai.secrets.confirm_delete"),
      didConfirm: () => {
        return this.args.model
          .destroyRecord()
          .then(() => {
            removeValueFromArray(this.args.secrets.content, this.args.model);
            this.router.transitionTo(
              "adminPlugins.show.discourse-ai-secrets.index"
            );
          })
          .catch(popupAjaxError);
      },
    });
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-ai-secrets"
      @label="discourse_ai.secrets.back"
    />
    <Form
      @onSubmit={{this.save}}
      @data={{this.formData}}
      class="ai-secret-editor"
      as |form|
    >
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

      <form.Actions>
        <form.Submit />

        {{#unless @model.isNew}}
          <form.Button
            @action={{this.delete}}
            @label="discourse_ai.secrets.delete"
            class="btn-danger"
          />
        {{/unless}}
      </form.Actions>
    </Form>
  </template>
}
