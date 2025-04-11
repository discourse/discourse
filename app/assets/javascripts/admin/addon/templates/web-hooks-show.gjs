import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import WebhookEvents from "admin/components/webhook-events";

export default RouteTemplate(
  <template>
    <LinkTo @route="adminWebHooks" class="go-back">
      {{icon "arrow-left"}}
      {{i18n "admin.web_hooks.back"}}
    </LinkTo>

    <div class="admin-webhooks__summary">
      <h1>
        {{@controller.model.payload_url}}

        <DButton
          @action={{@controller.edit}}
          @icon="far-pen-to-square"
          @title="admin.web_hooks.edit"
          class="no-text admin-webhooks__edit-button"
        />

        <DButton
          @action={{@controller.destroyWebhook}}
          @icon="xmark"
          @title="delete"
          class="destroy btn-danger admin-webhooks__delete-button"
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
      @webhookId={{@controller.model.id}}
      @status={{@controller.status}}
    />
  </template>
);
