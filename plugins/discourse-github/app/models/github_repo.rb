# frozen_string_literal: true

module DiscourseGithubPlugin
  class GithubRepo < ActiveRecord::Base
    VALID_URL_BASED_REPO_REGEX = %r{https?://github.com/(.+)}
    VALID_USER_BASED_REPO_REGEX = %r{\A[\w.-]+/[\w.-]+\z}i

    has_many :commits, foreign_key: :repo_id, class_name: :GithubCommit, dependent: :destroy

    def self.repos
      names.map { |name| find_or_create_by!(name:) }
    end

    def self.names
      SiteSetting
        .github_badges_repos
        .split("|")
        .filter_map do |link|
          name = link[VALID_URL_BASED_REPO_REGEX, 1] || link[VALID_USER_BASED_REPO_REGEX]
          name&.delete_suffix(".git")&.delete_suffix("/").presence
        end
    end
  end
end

# == Schema Information
#
# Table name: github_repos
#
#  id         :bigint           not null, primary key
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_github_repos_on_name  (name) UNIQUE
#
