# frozen_string_literal: true

class CreateDiscourseBoosts < ActiveRecord::Migration[7.2]
  def change
    create_table :discourse_boosts do |t|
      t.references :post, null: false
      t.references :user, null: false
      t.string :raw, limit: 16, null: false
      t.text :cooked, null: false
      t.timestamps
    end

    add_index :discourse_boosts, %i[post_id user_id]
  end
end
