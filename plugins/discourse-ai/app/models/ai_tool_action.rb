# frozen_string_literal: true

class AiToolAction < ActiveRecord::Base
  belongs_to :ai_agent
  validates :tool_name, presence: true
  validates :bot_user_id, presence: true
end
