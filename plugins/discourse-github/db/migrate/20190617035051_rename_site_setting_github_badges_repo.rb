# frozen_string_literal: true

class RenameSiteSettingGithubBadgesRepo < ActiveRecord::Migration[5.2]
  def up
    execute(<<~SQL)
      UPDATE site_settings SET name = 'github_badges_repos', data_type = 8 WHERE name = 'github_badges_repo' AND data_type = 1
    SQL
  end

  def down
    execute(<<~SQL)
      UPDATE site_settings SET name = 'github_badges_repo', data_type = 1 WHERE name = 'github_badges_repos' AND data_type = 8
    SQL
  end
end
