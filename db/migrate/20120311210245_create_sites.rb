class CreateSites < ActiveRecord::Migration
  def change
    create_table :sites  do |t|
      t.string :title, limit: 100, null: false
      t.timestamps
    end
  end
end
