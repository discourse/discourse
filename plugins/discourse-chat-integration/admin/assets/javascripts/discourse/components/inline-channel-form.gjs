import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class InlineChannelForm extends Component {
  @tracked isSaving = false;

  get channelParameters() {
    return this.args.provider?.channel_parameters || [];
  }

  get formData() {
    const data = {};
    this.channelParameters.forEach((param) => {
      data[param.key] = this.args.channel?.get(`data.${param.key}`) || "";
    });
    return data;
  }

  get isNew() {
    return this.args.channel?.isNew ?? true;
  }

  @action
  async onSubmit(data) {
    this.isSaving = true;

    this.channelParameters.forEach((param) => {
      this.args.channel.set(`data.${param.key}`, data[param.key]);
    });

    try {
      await this.args.channel.save();
      this.args.onSave?.();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    <div class="inline-channel-form">
      <Form @data={{this.formData}} @onSubmit={{this.onSubmit}} as |form|>
        <div class="inline-channel-form__fields">
          {{#each this.channelParameters as |param|}}
            <form.Field
              @type="input"
              @name={{param.key}}
              @format="full"
              @title={{i18n
                (concat
                  "chat_integration.provider."
                  @provider.name
                  ".param."
                  param.key
                  ".title"
                )
              }}
              @description={{i18n
                (concat
                  "chat_integration.provider."
                  @provider.name
                  ".param."
                  param.key
                  ".help"
                )
              }}
              @validation="required"
              as |field|
            >
              <field.Control />
            </form.Field>
          {{/each}}
        </div>

        <div class="inline-channel-form__actions">
          <form.Submit
            @label={{if
              this.isNew
              "chat_integration.add_channel"
              "chat_integration.edit_channel_modal.save"
            }}
            @isLoading={{this.isSaving}}
            class="btn-primary btn-small"
          />
          {{#if @onCancel}}
            <form.Button
              @label="cancel"
              @action={{@onCancel}}
              class="btn-default btn-small"
            />
          {{/if}}
        </div>
      </Form>
    </div>
  </template>
}
