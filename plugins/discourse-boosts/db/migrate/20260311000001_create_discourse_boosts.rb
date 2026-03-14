# frozen_string_literal: true

class CreateDiscourseBoosts < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_boosts do |t|
      t.integer :post_id, null: false
      t.integer :user_id, null: false
      t.string :raw, limit: 1000, null: false
      t.text :cooked, null: false
      t.timestamps
    end

    add_index :discourse_boosts, %i[post_id user_id], unique: true
  end
end
