# frozen_string_literal: true

class CreateCategoryLocalizationSearchData < ActiveRecord::Migration[8.1]
  def change
    create_table :category_localization_search_data, id: false do |t|
      t.bigint :category_localization_id, null: false, primary_key: true
      t.tsvector :search_data
      t.text :raw_data
      t.text :locale
      t.integer :version, default: 0
    end

    add_index :category_localization_search_data,
              :search_data,
              using: :gin,
              name: "idx_search_category_localization"
  end
end
