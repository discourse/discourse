# frozen_string_literal: true

class AiPersonaChatTopicRefactor < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_personas, :allow_chat_channel_mentions, :boolean, default: false, null: false
    add_column :ai_personas, :allow_chat_direct_messages, :boolean, default: false, null: false
    add_column :ai_personas, :allow_topic_mentions, :boolean, default: false, null: false
    add_column :ai_personas, :allow_personal_messages, :boolean, default: true, null: false
    add_column :ai_personas, :force_default_llm, :boolean, default: false, null: false

    execute <<~SQL
      UPDATE ai_personas
      SET allow_chat_channel_mentions = mentionable, allow_chat_direct_messages = true
      WHERE allow_chat = true
    SQL

    execute <<~SQL
      UPDATE ai_personas
      SET allow_topic_mentions = true
      WHERE mentionable = true
    SQL
  end
end
