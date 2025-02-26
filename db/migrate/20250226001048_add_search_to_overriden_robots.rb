# frozen_string_literal: true
class AddSearchToOverridenRobots < ActiveRecord::Migration[7.2]
  def up
    googlebot_agent_disallow =
      "User-agent: Googlebot\nDisallow: /admin/\nDisallow: /auth/\nDisallow: /assets/browser-update*.js\nDisallow: /email/\nDisallow: /session"
    googlebot_agent_disallow_search_added =
      "User-agent: Googlebot\nDisallow: /admin/\nDisallow: /auth/\nDisallow: /assets/browser-update*.js\nDisallow: /email/\nDisallow: /search\nDisallow: /session"
    if select_value(
         "SELECT value FROM site_settings WHERE name = 'overridden_robots_txt' AND value LIKE '%#{googlebot_agent_disallow}%'",
       )
      execute <<~SQL
        UPDATE site_settings
        SET value = REPLACE(value, '#{googlebot_agent_disallow}', '#{googlebot_agent_disallow_search_added}')
        WHERE name = 'overridden_robots_txt'
      SQL
    end
  end

  def down
    # raise ActiveRecord::IrreversibleMigration
  end
end
