# frozen_string_literal: true
class AddExternalPluginImportsToJavascriptCaches < ActiveRecord::Migration[8.0]
  def change
    add_column :javascript_caches,
               :external_plugin_imports,
               :string,
               array: true,
               null: false,
               default: []
  end
end
