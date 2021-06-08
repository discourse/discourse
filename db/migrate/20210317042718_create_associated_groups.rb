# frozen_string_literal: true
class CreateAssociatedGroups < ActiveRecord::Migration[6.0]
  def change
    create_table :associated_groups do |t|
      t.string :name, null: false
      t.string :provider_name, null: false
      t.string :provider_domain

      t.timestamps
    end

    add_index :associated_groups, %i[name provider_name provider_domain], unique: true, name: 'associated_groups_name_provider'
  end
end
