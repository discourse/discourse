class RemoveInvitePassthroughHours < ActiveRecord::Migration[5.1]
  def change
    execute "DELETE FROM site_settings WHERE name = 'invite_passthrough_hours'"
  end
end
