import RouteTemplate from "ember-route-template";
import { not } from "truth-helpers";
import BackButton from "discourse/components/back-button";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import ChatIncomingWebhookEditForm from "discourse/plugins/chat/admin/components/chat-incoming-webhook-edit-form";

export default RouteTemplate(
  <template>
    <div class="admin-detail discourse-chat-incoming-webhooks">
      <BackButton
        @label="chat.incoming_webhooks.back"
        @route="adminPlugins.show.discourse-chat-incoming-webhooks.index"
        class="incoming-chat-webhooks-back"
      />

      <ConditionalLoadingSpinner @condition={{not @controller.model.webhook}}>
        <ChatIncomingWebhookEditForm
          @webhook={{@controller.model.webhook}}
          @chatChannels={{@controller.model.chat_channels}}
        />
      </ConditionalLoadingSpinner>
    </div>
  </template>
);
