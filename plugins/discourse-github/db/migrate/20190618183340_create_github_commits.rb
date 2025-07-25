# frozen_string_literal: true

class CreateGithubCommits < ActiveRecord::Migration[5.2]
  def change
    create_table :github_commits do |t|
      t.references :repo, null: false
      t.string :sha, limit: 40, null: false
      t.string :email, limit: 513, null: false
      t.timestamp :committed_at, null: false
      t.integer :role_id, null: false
      t.boolean :merge_commit, null: false, default: false
      t.timestamps null: false
    end
  end
end
