# frozen_string_literal: true

class AiToolAction < ActiveRecord::Base
  belongs_to :ai_agent
  validates :tool_name, presence: true
  validates :bot_user_id, presence: true
end

# == Schema Information
#
# Table name: ai_tool_actions
#
#  id              :bigint           not null, primary key
#  tool_name       :string           not null
#  tool_parameters :jsonb            default({}), not null
#  bot_user_id     :integer          not null
#  post_id         :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ai_agent_id     :bigint           not null
#
# Indexes
#
#  index_ai_tool_actions_on_ai_agent_id  (ai_agent_id)
#
