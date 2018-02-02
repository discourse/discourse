class CreateThemeSettings < ActiveRecord::Migration[5.1]
  def change
    create_table :theme_settings do |t|
      t.string :name, limit: 255, null: false
      t.integer :data_type, null: false
      t.text :value
      t.references :theme, foreign_key: true, null: false

      t.timestamps null: false
    end
  end
end
