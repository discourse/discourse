class CreateBadgeTypes < ActiveRecord::Migration
  def change
    create_table :badge_types do |t|
      t.string :name, null: false
      t.string :color_hexcode, null: false

      t.timestamps
    end

    add_index :badge_types, [:name], unique: true
  end
end
