# frozen_string_literal: true

class AddSourceMapToJavascriptCache < ActiveRecord::Migration[7.0]
  def change
    add_column :javascript_caches, :source_map, :text
  end
end
