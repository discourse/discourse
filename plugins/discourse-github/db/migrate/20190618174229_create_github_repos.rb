# frozen_string_literal: true

class CreateGithubRepos < ActiveRecord::Migration[5.2]
  def change
    create_table :github_repos do |t|
      t.string :name, null: false, limit: 255
      t.timestamps null: false
    end
    add_index :github_repos, :name, unique: true
  end
end
