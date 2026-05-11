# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ConversationStar < ActiveRecord::Base
      MAX_STARS_PER_USER = 200

      self.table_name = "discourse_ai_ai_bot_conversation_stars"

      belongs_to :user
      belongs_to :topic

      validates :user_id, presence: true
      validates :topic_id, presence: true, uniqueness: { scope: :user_id }
    end
  end
end

# == Schema Information
#
# Table name: discourse_ai_ai_bot_conversation_stars
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  topic_id   :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  idx_ai_bot_conversation_stars_topic_id      (topic_id)
#  idx_ai_bot_conversation_stars_user_created  (user_id,created_at)
#  idx_ai_bot_conversation_stars_user_topic    (user_id,topic_id) UNIQUE
#
