# frozen_string_literal: true

class CreateStars < ActiveRecord::Migration[4.2]
  def change
    create_table :stars, id: false do |t|
      t.integer  :parent_id, null: false
      t.string   :parent_type, limit: 50, null: false
      t.integer  :user_id, null: true
      t.timestamps null: false
    end

    add_index :stars, [:parent_id, :parent_type, :user_id]
  end
end
