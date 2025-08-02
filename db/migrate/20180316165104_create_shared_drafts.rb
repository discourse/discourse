# frozen_string_literal: true

class CreateSharedDrafts < ActiveRecord::Migration[5.1]
  def change
    create_table :shared_drafts, id: false do |t|
      t.integer :topic_id, null: false
      t.integer :category_id, null: false
      t.timestamps
    end
    add_index :shared_drafts, :topic_id, unique: true
  end
end
