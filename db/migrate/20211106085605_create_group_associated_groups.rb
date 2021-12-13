# frozen_string_literal: true
class CreateGroupAssociatedGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :group_associated_groups do |t|
      t.references :group, null: false
      t.references :associated_group, null: false

      t.timestamps
    end

    add_index :group_associated_groups, %i[group_id associated_group_id], unique: true, name: 'index_group_associated_groups'
  end
end
