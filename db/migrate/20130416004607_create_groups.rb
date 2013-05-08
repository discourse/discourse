class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups, force: true do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
