# frozen_string_literal: true
class CreateAssociatedGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :associated_groups do |t|
      t.string :name, null: false
      t.string :provider_name, null: false
      t.string :provider_id, null: false
      t.datetime :last_used, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :associated_groups, %i[provider_name provider_id], unique: true, name: 'associated_groups_provider_id'
  end
end
