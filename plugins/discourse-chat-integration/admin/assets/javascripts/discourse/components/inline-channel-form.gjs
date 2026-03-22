import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
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

  get firstParam() {
    return this.channelParameters[0];
  }

  get firstParamPlaceholder() {
    if (!this.firstParam) {
      return "";
    }
    return i18n(
      `chat_integration.provider.${this.args.provider.name}.param.${this.firstParam.key}.help`
    );
  }

  get providerTitle() {
    return i18n(`chat_integration.provider.${this.args.provider.name}.title`);
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

  @action
  async onSimpleSubmit(event) {
    event.preventDefault();
    const input = event.target.querySelector("input");
    if (!input.value.trim()) {
      return;
    }

    this.isSaving = true;
    this.args.channel.set(`data.${this.firstParam.key}`, input.value.trim());

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
    {{#if @isFirstChannel}}
      <form
        class="chat-integration-add-first-channel"
        {{on "submit" this.onSimpleSubmit}}
      >
        <label>
          {{i18n
            "chat_integration.add_first_channel"
            provider=this.providerTitle
          }}
        </label>
        <div class="chat-integration-add-first-channel__input-row">
          <input
            type="text"
            placeholder={{this.firstParamPlaceholder}}
            class="chat-integration-add-first-channel__input"
          />
          <DButton
            @label="chat_integration.add_channel"
            @isLoading={{this.isSaving}}
            @type="submit"
            class="btn-primary"
          />
        </div>
      </form>
    {{else}}
      <div class="inline-channel-form">
        <Form @data={{this.formData}} @onSubmit={{this.onSubmit}} as |form|>
          <div class="inline-channel-form__fields">
            {{#each this.channelParameters as |param|}}
              <form.Field
                @name={{param.key}}
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
                <field.Input />
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
    {{/if}}
  </template>
}
