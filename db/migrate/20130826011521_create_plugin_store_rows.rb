class CreatePluginStoreRows < ActiveRecord::Migration
  def change
    create_table :plugin_store_rows do |table|
      table.string :plugin_name, null: false
      table.string :key, null: false
      table.string :type_name, null: false
      # not the most efficient implementation but will do for now
      #  possibly in future we can add more tables so int and boolean etc values are
      #  not stored in text
      table.text :value
    end

    add_index :plugin_store_rows, [:plugin_name, :key], unique: true
  end
end
