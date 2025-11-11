# frozen_string_literal: true

class AddSharedAiConversations < ActiveRecord::Migration[7.0]
  def up
    create_table :shared_ai_conversations do |t|
      t.integer :user_id, null: false
      t.integer :target_id, null: false
      t.string :target_type, null: false, max_length: 100
      t.string :title, null: false, max_length: 1024
      t.string :llm_name, null: false, max_length: 1024
      t.jsonb :context, null: false
      t.string :share_key, null: false, index: { unique: true }
      t.string :excerpt, null: false, max_length: 10_000
      t.timestamps
    end

    add_index :shared_ai_conversations, %i[target_id target_type], unique: true
    add_index :shared_ai_conversations,
              %i[user_id target_id target_type],
              unique: true,
              name: "idx_shared_ai_conversations_user_target"
  end

  def down
    drop_table :shared_ai_conversations
  end
end
