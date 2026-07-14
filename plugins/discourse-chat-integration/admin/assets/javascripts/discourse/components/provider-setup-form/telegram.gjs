import { i18n } from "discourse-i18n";

const TelegramProviderSetupForm = <template>
  <@form.Field
    @name="chat_integration_telegram_access_token"
    @title={{i18n
      "chat_integration.setup_provider_modal.telegram.access_token.title"
    }}
    @description={{i18n
      "chat_integration.setup_provider_modal.telegram.access_token.description"
    }}
    @validation="required"
    @type="password"
    @format="full"
    as |field|
  >
    <field.Control data-1p-ignore />
  </@form.Field>
</template>;

export default TelegramProviderSetupForm;
