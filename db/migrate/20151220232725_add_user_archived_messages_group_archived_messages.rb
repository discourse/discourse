# frozen_string_literal: true

class AddUserArchivedMessagesGroupArchivedMessages < ActiveRecord::Migration[4.2]
  def change
    create_table :user_archived_messages do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.timestamps null: false
    end

    add_index :user_archived_messages, [:user_id, :topic_id], unique: true

    create_table :group_archived_messages do |t|
      t.integer :group_id, null: false
      t.integer :topic_id, null: false
      t.timestamps null: false
    end

    add_index :group_archived_messages, [:group_id, :topic_id], unique: true
  end
end
