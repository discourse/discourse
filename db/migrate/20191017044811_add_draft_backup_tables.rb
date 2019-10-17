# frozen_string_literal: true

class AddDraftBackupTables < ActiveRecord::Migration[6.0]
  def change

    create_table :backup_draft_topics do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.timestamps
    end

    create_table :backup_draft_posts do |t|
      t.integer :user_id, null: false
      t.integer :post_id, null: false
      t.string :key, null: false
      t.timestamps
    end

    add_index :backup_draft_posts, [:user_id, :key], unique: true
    add_index :backup_draft_posts, [:post_id], unique: true

    add_index :backup_draft_topics, [:user_id], unique: true
    add_index :backup_draft_topics, [:topic_id], unique: true
  end
end
