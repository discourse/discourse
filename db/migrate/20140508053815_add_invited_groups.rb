# frozen_string_literal: true

class AddInvitedGroups < ActiveRecord::Migration[4.2]
  def change
    create_table :invited_groups do |t|
      t.integer :group_id
      t.integer :invite_id
      t.timestamps null: false
    end
  end
end
