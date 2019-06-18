# frozen_string_literal: true

class AddPrimaryGroupIdToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :primary_group_id, :integer, null: true
  end
end
