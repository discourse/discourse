class CreateBadges < ActiveRecord::Migration
  def change
    create_table :badges do |t|
      t.string :name, null: false
      t.text :description
      t.integer :badge_type_id, index: true, null: false
      t.integer :grant_count, null: false, default: 0

      t.timestamps
    end

    add_index :badges, [:name], unique: true
  end
end
