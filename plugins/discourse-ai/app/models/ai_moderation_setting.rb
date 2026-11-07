# frozen_string_literal: true

class AiModerationSetting < ActiveRecord::Base
  belongs_to :llm_model, optional: true
  belongs_to :decision_model, optional: true
  belongs_to :ai_agent, class_name: "AiAgent", optional: true

  validates :setting_type, presence: true
  validates :setting_type, uniqueness: true
  validate :model_present

  def self.spam
    find_by(setting_type: :spam)
  end

  def custom_instructions
    data&.[]("custom_instructions")
  end

  private

  def model_present
    if llm_model_id.blank? && decision_model_id.blank?
      errors.add(:base, I18n.t("discourse_ai.spam_detection.model_missing"))
    end
  end
end

# == Schema Information
#
# Table name: ai_moderation_settings
#
#  id                :bigint           not null, primary key
#  data              :jsonb
#  setting_type      :enum             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  ai_agent_id       :bigint           default(-31), not null
#  decision_model_id :bigint
#  llm_model_id      :bigint
#
# Indexes
#
#  index_ai_moderation_settings_on_setting_type  (setting_type) UNIQUE
#
