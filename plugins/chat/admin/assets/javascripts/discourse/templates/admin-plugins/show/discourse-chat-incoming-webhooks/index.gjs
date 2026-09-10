import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import AdminChatIncomingWebhooksList from "discourse/plugins/chat/admin/components/admin-chat-incoming-webhooks-list";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "chat.incoming_webhooks.title"}}
    @path="/admin/plugins/chat/hooks"
  />

  <div class="discourse-chat-incoming-webhooks admin-detail">
    <DPageSubheader
      @descriptionLabel={{i18n "chat.incoming_webhooks.instructions"}}
      @titleLabel={{i18n "chat.incoming_webhooks.title"}}
    >
      <:actions as |actions|>
        <actions.Primary
          class="admin-incoming-webhooks-new"
          @icon="plus"
          @label="chat.incoming_webhooks.new"
          @route="adminPlugins.show.discourse-chat-incoming-webhooks.new"
          @routeModels="chat"
          @title="chat.incoming_webhooks.new"
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
