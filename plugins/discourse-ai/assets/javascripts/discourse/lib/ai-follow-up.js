/**
 * Whether the reader can continue an answer as a conversation with the
 * follow-up agent. Mirrors the server's checks, which refuse the conversation
 * otherwise.
 */
export function followUpAvailable(siteSettings, currentUser) {
  // only serialized for readers the AI bot is enabled for
  if (!siteSettings.ai_bot_enabled || !currentUser?.ai_enabled_chat_bots) {
    return false;
  }

  const agentId = parseInt(siteSettings.ai_ask_ai_follow_up_agent, 10);
  const agent = currentUser.ai_enabled_agents?.find(({ id }) => id === agentId);
  return Boolean(
    agent?.allow_personal_messages && agent.username && agent.has_default_llm
  );
}
