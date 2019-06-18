# frozen_string_literal: true

class RemoveInvitePassthroughHours < ActiveRecord::Migration[5.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'invite_passthrough_hours'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
