# frozen_string_literal: true

class CreateAiBotConversationStars < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_ai_ai_bot_conversation_stars do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.timestamps
    end

    add_index :discourse_ai_ai_bot_conversation_stars,
              %i[user_id topic_id],
              unique: true,
              name: "idx_ai_bot_conversation_stars_user_topic"

    add_index :discourse_ai_ai_bot_conversation_stars,
              %i[user_id created_at],
              name: "idx_ai_bot_conversation_stars_user_created"

    add_index :discourse_ai_ai_bot_conversation_stars,
              :topic_id,
              name: "idx_ai_bot_conversation_stars_topic_id"
  end
end
