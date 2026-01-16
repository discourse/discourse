import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class EditChannel extends Component {
  @tracked formData = this.buildFormData();

  buildFormData() {
    const data = {};
    this.args.model.provider.channel_parameters.forEach((param) => {
      data[param.key] = this.args.model.channel.get(`data.${param.key}`) || "";
    });
    return data;
  }

  validateParam(value, param) {
    if (!value?.trim()) {
      return i18n(
        "chat_integration.edit_channel_modal.channel_validation.fail"
      );
    }

    if (param.regex && !new RegExp(param.regex).test(value)) {
      return i18n(
        "chat_integration.edit_channel_modal.channel_validation.fail"
      );
    }

    return null;
  }

  @action
  async onSubmit(data) {
    this.args.model.provider.channel_parameters.forEach((param) => {
      this.args.model.channel.set(`data.${param.key}`, data[param.key]);
    });

    try {
      await this.args.model.channel.save();
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @title={{i18n "chat_integration.edit_channel_modal.title"}}
      @closeModal={{@closeModal}}
      id="chat-integration-edit-channel-modal"
      class="chat-integration-modal"
    >
      <:body>
        <Form @data={{this.formData}} @onSubmit={{this.onSubmit}} as |form|>
          <form.Field
            @name="provider"
            @title={{i18n "chat_integration.edit_channel_modal.provider"}}
            @disabled={{true}}
            as |field|
          >
            <field.Custom>
              <span class="provider-name">
                {{i18n
                  (concat
                    "chat_integration.provider."
                    @model.channel.provider
                    ".title"
                  )
                }}
              </span>
            </field.Custom>
          </form.Field>

          {{#each @model.provider.channel_parameters as |param|}}
            <form.Field
              @name={{param.key}}
              @title={{i18n
                (concat
                  "chat_integration.provider."
                  @model.channel.provider
                  ".param."
                  param.key
                  ".title"
                )
              }}
              @description={{i18n
                (concat
                  "chat_integration.provider."
                  @model.channel.provider
                  ".param."
                  param.key
                  ".help"
                )
              }}
              @validation="required"
              as |field|
            >
              <field.Input />
            </form.Field>
          {{/each}}

          <form.Actions>
            <form.Submit
              @label="chat_integration.edit_channel_modal.save"
              class="btn-primary"
              id="save-channel"
            />
            <form.Button
              @label="chat_integration.edit_channel_modal.cancel"
              @action={{@closeModal}}
              class="btn-default"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
