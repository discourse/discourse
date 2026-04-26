# frozen_string_literal: true

class AiModerationSetting < ActiveRecord::Base
  belongs_to :llm_model
  belongs_to :ai_agent, class_name: "AiAgent", optional: true

  validates :llm_model_id, presence: true
  validates :setting_type, presence: true
  validates :setting_type, uniqueness: true

  def self.spam
    find_by(setting_type: :spam)
  end

  def custom_instructions
    data&.[]("custom_instructions")
  end
end

# == Schema Information
#
# Table name: ai_moderation_settings
#
#  id           :bigint           not null, primary key
#  data         :jsonb
#  setting_type :enum             not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  ai_agent_id  :bigint           default(-31), not null
#  llm_model_id :bigint           not null
#
# Indexes
#
#  index_ai_moderation_settings_on_setting_type  (setting_type) UNIQUE
#
