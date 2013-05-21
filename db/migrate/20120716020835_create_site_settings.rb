class CreateSiteSettings < ActiveRecord::Migration
  def change
    create_table :site_settings do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.integer :data_type, null: false
      t.text :value

      t.timestamps
    end
  end
end
