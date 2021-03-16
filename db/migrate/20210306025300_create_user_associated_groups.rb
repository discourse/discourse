# frozen_string_literal: true
class CreateUserAssociatedGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :user_associated_groups do |t|
      t.string :provider_name, null: false
      t.string :provider_domain, null: true
      t.integer :user_id, null: false
      t.string :group, null: false

      t.timestamps
    end

    add_index :user_associated_groups, [:provider_name, :provider_domain, :group], unique: false, name: 'associated_groups_provider_group'
    add_index :user_associated_groups, [:provider_name, :user_id, :group], unique: true, name: 'associated_groups_provider_user_group'
  end
end
