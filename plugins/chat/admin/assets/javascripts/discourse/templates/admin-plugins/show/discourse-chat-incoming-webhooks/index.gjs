import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import AdminChatIncomingWebhooksList from "discourse/plugins/chat/admin/components/admin-chat-incoming-webhooks-list";

export default RouteTemplate(
  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/chat/hooks"
      @label={{i18n "chat.incoming_webhooks.title"}}
    />

    <div class="discourse-chat-incoming-webhooks admin-detail">
      <DPageSubheader
        @titleLabel={{i18n "chat.incoming_webhooks.title"}}
        @descriptionLabel={{i18n "chat.incoming_webhooks.instructions"}}
      >
        <:actions as |actions|>
          <actions.Primary
            @label="chat.incoming_webhooks.new"
            @title="chat.incoming_webhooks.new"
            @route="adminPlugins.show.discourse-chat-incoming-webhooks.new"
            @routeModels="chat"
            @icon="plus"
            class="admin-incoming-webhooks-new"
          />
        </:actions>
      </DPageSubheader>

      <div class="incoming-chat-webhooks">
        {{#if @controller.model.incoming_chat_webhooks}}
          <AdminChatIncomingWebhooksList
            @webhooks={{@controller.model.incoming_chat_webhooks}}
          />
        {{else}}
          {{i18n "chat.incoming_webhooks.none"}}
        {{/if}}
      </div>
    </div>
  </template>
);
