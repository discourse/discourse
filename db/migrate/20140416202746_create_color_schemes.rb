class CreateColorSchemes < ActiveRecord::Migration
  def change
    create_table :color_schemes do |t|
      t.string  :name,         null: false
      t.boolean :enabled,      null: false, default: false

      t.integer :versioned_id
      t.integer :version,      null: false, default: 1

      t.timestamps
    end
  end
end
