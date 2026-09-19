# frozen_string_literal: true

Fabricator(:ai_bot_conversation_star, from: "DiscourseAi::AiBot::ConversationStar") do
  user
  topic { Fabricate(:private_message_topic) }
end
