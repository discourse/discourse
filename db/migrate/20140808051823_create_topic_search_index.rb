# frozen_string_literal: true

class CreateTopicSearchIndex < ActiveRecord::Migration[4.2]
  def up
    # used for similarity search
    create_table :topic_search_data, id: false do |t|
      t.integer :topic_id, null: false, primary_key: true
      t.text :raw_data
      t.string :locale, null: false
      t.tsvector :search_data
    end

    execute "CREATE INDEX idx_search_topic ON topic_search_data USING gin (search_data)"
  end

  def down
    drop_table :topic_search_data
  end
end
