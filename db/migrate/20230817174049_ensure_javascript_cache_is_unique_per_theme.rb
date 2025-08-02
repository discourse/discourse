# frozen_string_literal: true

class EnsureJavascriptCacheIsUniquePerTheme < ActiveRecord::Migration[7.0]
  def change
    remove_index :javascript_caches, :theme_id
    add_index :javascript_caches, :theme_id, unique: true

    remove_index :javascript_caches, :theme_field_id
    add_index :javascript_caches, :theme_field_id, unique: true
  end
end
