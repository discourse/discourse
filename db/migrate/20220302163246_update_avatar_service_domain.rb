# frozen_string_literal: true

class UpdateAvatarServiceDomain < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET value = REPLACE(value, 'avatars.discourse.org', 'avatars.discourse-cdn.com')
      WHERE name = 'external_system_avatars_url'
      AND value LIKE '%avatars.discourse.org%'
    SQL
  end

  def down
    # Nothing to do
  end
end
