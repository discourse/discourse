# frozen_string_literal: true
class UpdateJavascriptCache < ActiveRecord::Migration[7.2]
  def change
    remove_index :javascript_caches,
                 column: :theme_field_id,
                 name: :index_javascript_caches_on_theme_field_id,
                 unique: true
    add_column :javascript_caches, :name, :string
    add_index :javascript_caches,
              %i[theme_field_id name],
              unique: true,
              nulls_not_distinct: true,
              where: "theme_field_id IS NOT NULL"
  end
end
