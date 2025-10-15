import BackButton from "discourse/components/back-button";
import ChatIncomingWebhookEditForm from "discourse/plugins/chat/admin/components/chat-incoming-webhook-edit-form";

<template>
  <div class="admin-detail discourse-chat-incoming-webhooks">
    <BackButton
      @label="chat.incoming_webhooks.back"
      @route="adminPlugins.show.discourse-chat-incoming-webhooks.index"
      class="incoming-chat-webhooks-back"
    />

    <ChatIncomingWebhookEditForm
      @chatChannels={{@controller.model.chat_channels}}
    />
  </div>
</template>
