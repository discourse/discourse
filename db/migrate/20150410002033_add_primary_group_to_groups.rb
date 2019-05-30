# frozen_string_literal: true

class AddPrimaryGroupToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :primary_group, :boolean, default: false, null: false
  end
end
