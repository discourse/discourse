# frozen_string_literal: true

class CreateStandaloneBookmarksTable < ActiveRecord::Migration[6.0]
  def up
    create_table :bookmarks do |t|
      t.bigint :user_id, null: false
      t.bigint :topic_id, null: false
      t.bigint :post_id, null: false
      t.string :name, null: true
      t.integer :reminder_type, null: true, index: true
      t.datetime :reminder_at, null: true, index: true

      t.timestamps
    end

    add_index :bookmarks, [:user_id, :post_id], unique: true
    add_index :bookmarks, :user_id
    add_index :bookmarks, :topic_id
    add_index :bookmarks, :post_id
  end

  def down
    drop_table(:bookmarks) if table_exists?(:bookmarks)
  end
end
