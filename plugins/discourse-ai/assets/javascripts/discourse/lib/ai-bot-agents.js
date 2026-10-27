/**
 * @param {Object} currentUser
 * @param {Object} siteSettings
 * @returns {Array<Object>} The agents the user can start a conversation with:
 * those taking personal messages that have a model to answer with, their own
 * or one the user picks.
 */
export function conversationAgents(currentUser, siteSettings) {
  if (!siteSettings.ai_bot_enabled || !currentUser?.ai_available_llm_models) {
    return [];
  }

  const hasSelectableModel = currentUser.ai_available_llm_models.length > 0;

  return (currentUser.ai_enabled_agents || []).filter(
    (agent) =>
      agent.allow_personal_messages &&
      (agent.has_default_llm || hasSelectableModel)
  );
}
