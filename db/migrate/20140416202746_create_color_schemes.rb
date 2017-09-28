class CreateColorSchemes < ActiveRecord::Migration[4.2]
  def change
    create_table :color_schemes do |t|
      t.string  :name,         null: false
      t.boolean :enabled,      null: false, default: false

      t.integer :versioned_id
      t.integer :version,      null: false, default: 1

      t.timestamps null: false
    end
  end
end
