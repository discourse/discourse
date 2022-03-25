# frozen_string_literal: true

class CreatePublishedPages < ActiveRecord::Migration[6.0]
  def change
    create_table :published_pages do |t|
      t.bigint :topic_id, null: false
      t.string :slug, null: false
      t.timestamps
    end

    add_index :published_pages, :topic_id, unique: true
    add_index :published_pages, :slug, unique: true
  end
end
