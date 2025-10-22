# frozen_string_literal: true
class AddThemeSiteSettingTable < ActiveRecord::Migration[7.2]
  def change
    create_table :theme_site_settings do |t|
      t.integer :theme_id, null: false
      t.string :name, null: false
      t.integer :data_type, null: false
      t.text :value
      t.timestamps

      t.index :theme_id
      t.index %i[theme_id name], unique: true
    end
  end
end
