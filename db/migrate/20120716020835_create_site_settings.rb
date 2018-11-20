class CreateSiteSettings < ActiveRecord::Migration[4.2]
  def change
    create_table :site_settings do |t|
      t.string :name, null: false
      t.text :description, null: false
      t.integer :data_type, null: false
      t.text :value

      t.timestamps null: false
    end
  end
end
