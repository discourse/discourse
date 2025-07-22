# frozen_string_literal: true

module DiscourseGithubPlugin
  class GithubCommit < ActiveRecord::Base
    belongs_to :repo, class_name: :GithubRepo
  end
end

# == Schema Information
#
# Table name: github_commits
#
#  id           :bigint           not null, primary key
#  repo_id      :bigint           not null
#  sha          :string(40)       not null
#  email        :string(513)      not null
#  committed_at :datetime         not null
#  role_id      :integer          not null
#  merge_commit :boolean          default(FALSE), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_github_commits_on_repo_id  (repo_id)
#
