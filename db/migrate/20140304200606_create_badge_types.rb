# frozen_string_literal: true

class CreateBadgeTypes < ActiveRecord::Migration[4.2]
  def change
    create_table :badge_types do |t|
      t.string :name, null: false
      t.string :color_hexcode, null: false

      t.timestamps null: false
    end

    add_index :badge_types, [:name], unique: true
  end
end
