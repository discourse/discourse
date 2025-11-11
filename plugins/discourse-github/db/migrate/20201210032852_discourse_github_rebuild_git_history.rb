# frozen_string_literal: true

class DiscourseGithubRebuildGitHistory < ActiveRecord::Migration[6.0]
  def up
    # the table will be repopulated the next time the `UpdateJob` runs.
    # This will not have any noticeable effects on the site because
    # this table is merely used to grant the committer and contributor
    # badges. Deleting commits will not cause users to lose badges.
    execute "DELETE FROM github_commits"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
