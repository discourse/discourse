# frozen_string_literal: true

class UpdateAvatarServiceDomain < ActiveRecord::Migration[6.1]
  def up
    existing_value =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'external_system_avatars_url'",
      )&.[](0)

    if existing_value&.include?("avatars.discourse.org")
      new_value = DB.query_single(<<~SQL)&.[](0)
        UPDATE site_settings
        SET value = REPLACE(value, 'avatars.discourse.org', 'avatars.discourse-cdn.com')
        WHERE name = 'external_system_avatars_url'
        AND value LIKE '%avatars.discourse.org%'
        RETURNING value
      SQL

      DB.exec <<~SQL, previous: existing_value, new: new_value
        INSERT INTO user_histories
        (action, subject, previous_value, new_value, admin_only, updated_at, created_at, acting_user_id)
        VALUES (3, 'external_system_avatars_url', :previous, :new, true, NOW(), NOW(), -1)
      SQL
    end
  end

  def down
    # Nothing to do
  end
end
