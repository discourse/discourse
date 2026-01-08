# frozen_string_literal: true

class RenameGithubPullRequestDiffToGithubDiff < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE ai_personas
      SET tools = REPLACE(tools::text, '"GithubPullRequestDiff"', '"GithubDiff"')::json
      WHERE tools::text LIKE '%GithubPullRequestDiff%'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE ai_personas
      SET tools = REPLACE(tools::text, '"GithubDiff"', '"GithubPullRequestDiff"')::json
      WHERE tools::text LIKE '%GithubDiff%'
    SQL
  end
end
