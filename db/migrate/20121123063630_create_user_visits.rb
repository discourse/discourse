# frozen_string_literal: true

class CreateUserVisits < ActiveRecord::Migration[4.2]
  def change
    create_table :user_visits do |t|
      t.integer :user_id, null: false
      t.date :visited_at, null: false
    end

    add_index :user_visits, [:user_id, :visited_at], unique: true
  end
end
