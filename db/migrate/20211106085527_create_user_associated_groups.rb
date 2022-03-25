# frozen_string_literal: true
class CreateUserAssociatedGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :user_associated_groups do |t|
      t.bigint :user_id, null: false
      t.bigint :associated_group_id, null: false

      t.timestamps
    end

    add_index :user_associated_groups, %i[user_id associated_group_id], unique: true, name: 'index_user_associated_groups'
    add_index :user_associated_groups, :user_id
    add_index :user_associated_groups, :associated_group_id
  end
end
