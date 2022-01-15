# frozen_string_literal: true
class CreateUserAssociatedGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :user_associated_groups do |t|
      t.references :user, null: false
      t.references :associated_group, null: false

      t.timestamps
    end

    add_index :user_associated_groups, %i[user_id associated_group_id], unique: true, name: 'index_user_associated_groups'
  end
end
