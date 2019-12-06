# frozen_string_literal: true

class CreateStandaloneBookmarksTable < ActiveRecord::Migration[6.0]
  def up
    create_table :bookmarks do |t|
      t.references :user, index: true, foreign_key: true, null: false
      t.references :topic, index: true, foreign_key: true, null: true
      t.references :post, index: true, foreign_key: true, null: false
      t.string :name, null: true
      t.integer :reminder_type, null: true, index: true
      t.datetime :reminder_at, null: true, index: true

      t.timestamps
    end

    add_index :bookmarks, [:user_id, :post_id], unique: true
  end

  def down
    drop_table(:bookmarks) if table_exists?(:bookmarks)
  end
end
