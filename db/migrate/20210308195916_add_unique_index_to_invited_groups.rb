# frozen_string_literal: true

class AddUniqueIndexToInvitedGroups < ActiveRecord::Migration[6.0]
  def change
    execute <<~SQL
      DELETE FROM invited_groups a
      USING invited_groups b
      WHERE a.id < b.id
        AND a.invite_id = b.invite_id
        AND a.group_id = b.group_id
    SQL

    add_index :invited_groups, %i[group_id invite_id], unique: true
  end
end
