# frozen_string_literal: true

module DiscourseGithubPlugin
  class GithubRepo < ActiveRecord::Base
    VALID_URL_BASED_REPO_REGEX = %r{https?://github.com/(.+)}
    VALID_USER_BASED_REPO_REGEX = Octokit::Repository::NAME_WITH_OWNER_PATTERN

    has_many :commits, foreign_key: :repo_id, class_name: :GithubCommit, dependent: :destroy

    def self.repos
      repos = []
      SiteSetting
        .github_badges_repos
        .split("|")
        .each do |link|
          name = match_name_from_setting(link)
          next if name.blank?
          name.gsub!(/\.git$/, "")
          name.gsub!(%r{/$}, "") # Remove trailing '/'
          repos << find_or_create_by!(name: name)
        end
      repos
    end

    def self.match_name_from_setting(repo)
      if repo =~ VALID_URL_BASED_REPO_REGEX
        Regexp.last_match[1]
      elsif repo =~ VALID_USER_BASED_REPO_REGEX
        repo_name = Regexp.last_match[0]
        repo.match(/https?:/).blank? ? repo_name : nil
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
