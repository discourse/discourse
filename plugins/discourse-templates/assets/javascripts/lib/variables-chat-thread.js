import extractVariablesFromChatChannel from "./variables-chat-channel";

export default function extractVariablesFromChatThread(
  thread,
  message,
  router
) {
  if (!thread && !message) {
    return {};
  }

  const channel = thread?.channel;
  const inReplyTo = thread?.originalMessage;

  const channelVariables = extractVariablesFromChatChannel(
    channel,
    message,
    router
  );

  const threadVariables = {
    chat_thread_name: thread?.title,
    chat_thread_url: thread?.routeModels
      ? router?.urlFor("chat.channel.thread", ...thread.routeModels)
      : null,
    reply_to_username: inReplyTo?.user?.username,
    reply_to_name: inReplyTo?.user?.name,
  };

  return {
    ...channelVariables,
    ...threadVariables,
    context_title:
      threadVariables.chat_thread_name || channelVariables.chat_channel_name,
    context_url:
      threadVariables.chat_thread_url || channelVariables.chat_channel_url,
  };
}
