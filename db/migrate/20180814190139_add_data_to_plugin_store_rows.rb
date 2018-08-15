class AddDataToPluginStoreRows < ActiveRecord::Migration[5.2]
  def change
    add_column :plugin_store_rows, :data, :jsonb
  end
end
