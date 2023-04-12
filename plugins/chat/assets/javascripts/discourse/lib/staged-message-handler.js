export function handleStagedMessage(messagesManager, data) {
  const stagedMessage = messagesManager.findStagedMessage(data.stagedId);

  if (!stagedMessage) {
    return;
  }

  stagedMessage.error = null;
  stagedMessage.id = data.chat_message.id;
  stagedMessage.staged = false;
  stagedMessage.excerpt = data.chat_message.excerpt;
  stagedMessage.threadId = data.chat_message.thread_id;
  stagedMessage.channelId = data.chat_message.chat_channel_id;
  stagedMessage.createdAt = data.chat_message.created_at;

  const inReplyToMsg = messagesManager.findMessage(
    data.chat_message.in_reply_to?.id
  );
  if (inReplyToMsg && !inReplyToMsg.threadId) {
    inReplyToMsg.threadId = data.chat_message.thread_id;
  }

  // some markdown is cooked differently on the server-side, e.g.
  // quotes, avatar images etc.
  if (data.chat_message?.cooked !== stagedMessage.cooked) {
    stagedMessage.cooked = data.chat_message.cooked;
  }
}
