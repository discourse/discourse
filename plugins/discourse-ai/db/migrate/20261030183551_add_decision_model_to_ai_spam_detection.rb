# frozen_string_literal: true
class AddDecisionModelToAiSpamDetection < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_moderation_settings, :decision_model_id, :bigint
    change_column_null :ai_moderation_settings, :llm_model_id, true

    add_column :ai_spam_logs, :decision_model_id, :bigint
    add_column :ai_spam_logs, :spam_probability, :float
    change_column_null :ai_spam_logs, :llm_model_id, true
  end
end
