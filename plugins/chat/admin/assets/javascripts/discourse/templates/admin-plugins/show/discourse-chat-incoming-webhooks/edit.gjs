import BackButton from "discourse/components/back-button";
import { not } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import ChatIncomingWebhookEditForm from "discourse/plugins/chat/admin/components/chat-incoming-webhook-edit-form";

export default <template>
  <div class="admin-detail discourse-chat-incoming-webhooks">
    <BackButton
      @label="chat.incoming_webhooks.back"
      @route="adminPlugins.show.discourse-chat-incoming-webhooks.index"
      class="incoming-chat-webhooks-back"
    />

    <DConditionalLoadingSpinner @condition={{not @controller.model.webhook}}>
      <ChatIncomingWebhookEditForm
        @webhook={{@controller.model.webhook}}
        @chatChannels={{@controller.model.chat_channels}}
      />
    </DConditionalLoadingSpinner>
  </div>
</template>
