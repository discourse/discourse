# frozen_string_literal: true

module DiscourseAi
  module AiBot
    USER_AGENT = "Discourse AI Bot 1.0 (https://www.discourse.org)"
    TOPIC_AI_BOT_PM_FIELD = "is_ai_bot_pm"
    POST_AI_LLM_NAME_FIELD = "ai_llm_name"
    POST_AI_LLM_MODEL_ID_FIELD = "ai_llm_model_id"
    POST_AI_AGENT_ID_FIELD = "ai_agent_id"
    POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD = "ai_agent_authorization_user_id"
    TOPIC_AI_AGENT_ID_FIELD = "ai_agent_id"
    TOPIC_AI_AGENT_ID_MAX_LENGTH = 20
    PERSONAL_MESSAGE_CONTEXT = "discourse_ai.ai_bot_personal_message"
  end
end
