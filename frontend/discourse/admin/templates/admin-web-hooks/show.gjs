import WebhookEvents from "discourse/admin/components/webhook-events";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader @hideTabs={{true}}>
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/api/web_hooks"
        @label={{i18n "admin.config.webhooks.title"}}
      />
      <DBreadcrumbsItem @label={{i18n "admin.config.webhooks.status"}} />
    </:breadcrumbs>
  </DPageHeader>

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
