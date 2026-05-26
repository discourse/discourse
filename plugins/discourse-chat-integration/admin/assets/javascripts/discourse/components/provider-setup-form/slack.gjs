import { i18n } from "discourse-i18n";

const SlackProviderSetupForm = <template>
  <@form.Field
    @name="chat_integration_slack_access_token"
    @title={{i18n
      "chat_integration.setup_provider_modal.slack.access_token.title"
    }}
    @description={{i18n
      "chat_integration.setup_provider_modal.slack.access_token.description"
    }}
    @type="password"
    @format="full"
    as |field|
  >
    <field.Control data-1p-ignore />
  </@form.Field>

  <@form.Field
    @name="chat_integration_slack_outbound_webhook_url"
    @title={{i18n
      "chat_integration.setup_provider_modal.slack.outbound_webhook_url.title"
    }}
    @description={{i18n
      "chat_integration.setup_provider_modal.slack.outbound_webhook_url.description"
    }}
    @type="input"
    @format="full"
    as |field|
  >
    <field.Control data-1p-ignore />
  </@form.Field>
</template>;

export default SlackProviderSetupForm;
