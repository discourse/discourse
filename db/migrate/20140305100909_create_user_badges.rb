# frozen_string_literal: true

class CreateUserBadges < ActiveRecord::Migration[4.2]
  def change
    create_table :user_badges do |t|
      t.integer :badge_id, null: false
      t.integer :user_id, index: true, null: false
      t.datetime :granted_at, null: false
      t.integer :granted_by_id, null: false
    end

    add_index :user_badges, [:badge_id, :user_id], unique: true
  end
end
