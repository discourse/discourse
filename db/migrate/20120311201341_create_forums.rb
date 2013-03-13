class CreateForums < ActiveRecord::Migration
  def change
    create_table :forums do |t|
      t.integer :site_id, null: false
      t.string :title, limit: 100, null: false
      t.timestamps
    end
  end
end
