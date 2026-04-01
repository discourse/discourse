import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import SlackProviderSetupForm from "../provider-setup-form/slack";
import TelegramProviderSetupForm from "../provider-setup-form/telegram";

export default class SetupProvider extends Component {
  @service toasts;

  get formComponent() {
    switch (this.args.model.provider.name) {
      case "slack":
        return SlackProviderSetupForm;
      case "telegram":
        return TelegramProviderSetupForm;
      default:
        return null;
    }
  }

  get additionalInstructions() {
    switch (this.args.model.provider.name) {
      case "slack":
        return i18n("chat_integration.setup_provider_modal.slack.instructions");
      default:
        return "";
    }
  }

  @action
  async save(data) {
    try {
      await ajax("/admin/plugins/discourse-chat-integration/setup-provider", {
        type: "POST",
        data: {
          provider: {
            name: this.args.model.provider.name,
          },
          provider_site_settings: data,
        },
      });
      this.toasts.success({
        data: {
          message: i18n("chat_integration.setup_provider_modal.success", {
            provider: this.args.model.provider.title,
          }),
        },
        duration: "short",
      });
      this.args.closeModal({ setupCompleted: true });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @title={{i18n
        "chat_integration.setup_provider_modal.title"
        provider=(i18n
          (concat "chat_integration.provider." @model.provider.name ".title")
        )
      }}
      @closeModal={{@closeModal}}
      id="chat-integration-setup-provider-modal"
      class="chat-integration-modal"
    >
      <:body>
        <p>
          {{i18n
            "chat_integration.setup_provider_modal.setup_instructions"
            provider=@model.provider.title
            additionalInstructions=this.additionalInstructions
          }}
        </p>
        <Form @onSubmit={{this.save}} as |form|>
          <this.formComponent @form={{form}} />

          <form.Actions>
            <form.Submit
              @label="chat_integration.setup_provider_modal.confirm_setup"
              class="btn-primary"
              id="save-rule"
            />
            <form.Button
              @label="cancel"
              @action={{@closeModal}}
              class="btn-default"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
