# frozen_string_literal: true

class CreateDataExplorerQueryTags < ActiveRecord::Migration[8.0]
  def change
    create_table :data_explorer_tags do |t|
      t.string :name, null: false, limit: 100
      t.timestamps null: false
    end
    add_index :data_explorer_tags, :name, unique: true, name: "idx_data_explorer_tags_on_name"

    create_table :data_explorer_query_tags do |t|
      t.bigint :query_id, null: false
      t.bigint :query_tag_id, null: false
      t.datetime :created_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :data_explorer_query_tags,
              %i[query_id query_tag_id],
              unique: true,
              name: "idx_data_explorer_query_tags_on_query_tag"
    add_index :data_explorer_query_tags,
              %i[query_tag_id query_id],
              unique: true,
              name: "idx_data_explorer_query_tags_on_tag_query"
  end
end
