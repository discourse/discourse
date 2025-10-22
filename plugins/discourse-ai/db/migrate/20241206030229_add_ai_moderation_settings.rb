# frozen_string_literal: true
class AddAiModerationSettings < ActiveRecord::Migration[7.2]
  def change
    create_enum :ai_moderation_setting_type, %w[spam nsfw custom]

    create_table :ai_moderation_settings do |t|
      t.enum :setting_type, enum_type: "ai_moderation_setting_type", null: false
      t.jsonb :data, default: {}
      t.bigint :llm_model_id, null: false
      t.timestamps
    end

    add_index :ai_moderation_settings, :setting_type, unique: true
  end
end
