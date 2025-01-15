# frozen_string_literal: true
class RemoveUserProfileFromOverriddenRobots < ActiveRecord::Migration[7.2]
  def up
    all_agent_user_disallow =
      "User-agent: *\nDisallow: /admin/\nDisallow: /auth/\nDisallow: /assets/browser-update*.js\nDisallow: /email/\nDisallow: /session\nDisallow: /user-api-key\nDisallow: /*?api_key*\nDisallow: /*?*api_key*\nDisallow: /badges\nDisallow: /u/"
    all_agent_user_disallow_removed = all_agent_user_disallow.gsub("\nDisallow: /u/", "")
    if select_value(
         "SELECT value FROM site_settings WHERE name = 'overridden_robots_txt' AND value LIKE '%#{all_agent_user_disallow}%'",
       )
      execute <<~SQL
        UPDATE site_settings
        SET value = REPLACE(value, '#{all_agent_user_disallow}', '#{all_agent_user_disallow_removed}')
        WHERE name = 'overridden_robots_txt'
      SQL
    end
  end

  def down
    # raise ActiveRecord::IrreversibleMigration
  end
end
