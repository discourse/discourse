import BackButton from "discourse/components/back-button";
import { not } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import ChatIncomingWebhookEditForm from "discourse/plugins/chat/admin/components/chat-incoming-webhook-edit-form";

export default <template>
  <div class="admin-detail discourse-chat-incoming-webhooks">
    <BackButton
      class="incoming-chat-webhooks-back"
      @label="chat.incoming_webhooks.back"
      @route="adminPlugins.show.discourse-chat-incoming-webhooks.index"
    />

    <DConditionalLoadingSpinner @condition={{not @controller.model.webhook}}>
      <ChatIncomingWebhookEditForm
        @chatChannels={{@controller.model.chat_channels}}
        @webhook={{@controller.model.webhook}}
      />
    </DConditionalLoadingSpinner>
  </div>
</template>
