# frozen_string_literal: true
class AddPersonaToAiModerationSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_moderation_settings, :ai_persona_id, :bigint, null: false, default: -31
  end
end
