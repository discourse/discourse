# frozen_string_literal: true

class GroupManagers < ActiveRecord::Migration[4.2]
  def change
    create_table :group_managers do |t|
      t.integer :group_id, null: false
      t.integer :user_id, null: false
      t.timestamps null: false
    end

    add_index :group_managers, [:group_id, :user_id], unique: true
  end
end
