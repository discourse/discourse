# frozen_string_literal: true

class CreateDiscourseWorkflowsChatConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :discourse_workflows_chat_conversations do |t|
      t.bigint :channel_id, null: false
      t.bigint :user_id, null: false
      t.bigint :bot_user_id, null: false
      t.bigint :workflow_id, null: false
      t.string :trigger_node_id, null: false, limit: 100
      t.boolean :draft, null: false, default: false
      t.timestamps
    end

    add_index :discourse_workflows_chat_conversations, :channel_id, unique: true
  end
end
