import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractErrorInfo, popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { PROVIDER_LEARN_MORE_URLS } from "../../lib/utilities";
import SlackProviderSetupForm from "../provider-setup-form/slack";
import TelegramProviderSetupForm from "../provider-setup-form/telegram";

export default class SetupProvider extends Component {
  @service toasts;

  @tracked formKitApi = null;

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
        return i18n(
          "chat_integration.setup_provider_modal.slack.instructions",
          {
            learnMoreUrl: PROVIDER_LEARN_MORE_URLS.slack,
          }
        );
      case "telegram":
        return i18n(
          "chat_integration.setup_provider_modal.telegram.instructions",
          {
            learnMoreUrl: PROVIDER_LEARN_MORE_URLS.telegram,
          }
        );
      default:
        return "";
    }
  }

  @action
  validateForm(data, { addError, removeError }) {
    if (this.args.model.provider.name === "slack") {
      this.validateSlackForm(data, addError, removeError);
    } else {
      return;
    }
  }

  get primaryFieldName() {
    switch (this.args.model.provider.name) {
      case "slack":
        return "chat_integration_slack_access_token";
      case "telegram":
        return "chat_integration_telegram_access_token";
      default:
        return null;
    }
  }

  get primaryFieldTitleKey() {
    switch (this.args.model.provider.name) {
      case "slack":
        return "chat_integration.setup_provider_modal.slack.access_token.title";
      case "telegram":
        return "chat_integration.setup_provider_modal.telegram.access_token.title";
      default:
        return null;
    }
  }

  fieldAndTitleForErrorKey(errorKey) {
    if (this.args.model.provider.name === "slack") {
      if (
        errorKey ===
        "chat_integration.provider.slack.errors.invalid_webhook_url"
      ) {
        return {
          field: "chat_integration_slack_outbound_webhook_url",
          titleKey:
            "chat_integration.setup_provider_modal.slack.outbound_webhook_url.title",
        };
      }
    }

    return {
      field: this.primaryFieldName,
      titleKey: this.primaryFieldTitleKey,
    };
  }

  @action
  registerFormApi(api) {
    this.formKitApi = api;
  }

  validateSlackForm(data, addError, removeError) {
    const token = data.chat_integration_slack_access_token;
    const url = data.chat_integration_slack_outbound_webhook_url;

    const tokenField = "chat_integration_slack_access_token";

    if (isEmpty(token) && isEmpty(url)) {
      addError(tokenField, {
        title: i18n(
          "chat_integration.setup_provider_modal.slack.access_token.title"
        ),
        message: i18n(
          "chat_integration.setup_provider_modal.slack.at_least_one_required"
        ),
      });
    } else {
      removeError(tokenField);
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
      const errorInfo = extractErrorInfo(error, undefined, {
        skipConsoleError: true,
      });

      if (errorInfo.status === 422 && errorInfo.errorKey && this.formKitApi) {
        const { field, titleKey } = this.fieldAndTitleForErrorKey(
          errorInfo.errorKey
        );
        if (field && titleKey) {
          this.formKitApi.addError(field, {
            title: i18n(titleKey),
            message: errorInfo.message,
          });
          return;
        }
      }

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
      class="chat-integration-setup-provider-modal"
    >
      <:body>
        <p class="chat-integration-setup-provider-modal__instructions">
          {{trustHTML
            (i18n
              "chat_integration.setup_provider_modal.setup_instructions"
              provider=@model.provider.title
              additionalInstructions=this.additionalInstructions
            )
          }}
        </p>
        <Form
          @onSubmit={{this.save}}
          @validate={{this.validateForm}}
          @onRegisterApi={{this.registerFormApi}}
          as |form|
        >
          <this.formComponent @form={{form}} />

          <form.Actions>
            <form.Submit
              @label="chat_integration.setup_provider_modal.confirm_setup"
              class="btn-primary"
              id="save-provider"
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
