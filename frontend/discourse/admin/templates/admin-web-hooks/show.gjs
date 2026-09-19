import { LinkTo } from "@ember/routing";
import WebhookEvents from "discourse/admin/components/webhook-events";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <LinkTo class="go-back" @route="adminWebHooks">
    {{dIcon "arrow-left"}}
    {{i18n "admin.web_hooks.back"}}
  </LinkTo>

  <div class="admin-webhooks__summary">
    <h1>
      {{@controller.model.payload_url}}

      <DButton
        class="btn-default no-text admin-webhooks__edit-button"
        @action={{@controller.edit}}
        @icon="far-pen-to-square"
        @title="admin.web_hooks.edit"
      />

      <DButton
        class="destroy btn-danger admin-webhooks__delete-button"
        @action={{@controller.destroyWebhook}}
        @icon="xmark"
        @title="delete"
      />
    </h1>

    <div>
      <span class="admin-webhooks__description-label">
        {{i18n "admin.web_hooks.description_label"}}:
      </span>

      {{@controller.model.description}}
    </div>
  </div>

  <WebhookEvents
    @status={{@controller.status}}
    @webhookId={{@controller.model.id}}
  />
</template>
