# frozen_string_literal: true

class CreateTagLocalizationSearchData < ActiveRecord::Migration[8.1]
  def change
    create_table :tag_localization_search_data, id: false do |t|
      t.bigint :tag_localization_id, null: false, primary_key: true
      t.tsvector :search_data
      t.text :raw_data
      t.text :locale
      t.integer :version, default: 0
    end

    add_index :tag_localization_search_data,
              :search_data,
              using: :gin,
              name: "idx_search_tag_localization"
  end
end
