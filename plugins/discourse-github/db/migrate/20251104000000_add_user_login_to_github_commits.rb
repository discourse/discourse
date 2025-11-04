# frozen_string_literal: true

class AddUserLoginToGithubCommits < ActiveRecord::Migration[7.2]
  def up
    # the table will be repopulated the next time the `UpdateJob` runs.
    # This will not have any noticeable effects on the site because
    # this table is merely used to grant the committer and contributor
    # badges. Deleting commits will not cause users to lose badges.
    execute <<~SQL
      DELETE FROM github_commits
    SQL

    unless column_exists?(:github_commits, :user_login)
      execute <<~SQL
        ALTER TABLE github_commits
        ADD COLUMN user_login VARCHAR
      SQL
    end
  end

  def down
    if column_exists?(:github_commits, :user_login)
      execute <<~SQL
        ALTER TABLE github_commits
        DROP COLUMN user_login
      SQL
    end
  end
end
