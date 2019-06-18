# frozen_string_literal: true

class RemoveUserActionPending < ActiveRecord::Migration[5.2]
  def up
    execute "DELETE FROM user_actions WHERE action_type = 14"
  end

  def down
  end
end
