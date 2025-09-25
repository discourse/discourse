# frozen_string_literal: true

# name: discourse-github
# about: Allows staff to assign badges to users based on GitHub contributions, and allows users to create Github Linkbacks and Permalinks
# meta_topic_id: 99895
# version: 0.3
# authors: Robin Ward, Sam Saffron
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-github

require "sawyer"
require "octokit"

# Site setting validators must be loaded before initialize
require_relative "app/lib/github_badges_repo_setting_validator"
require_relative "app/lib/github_linkback_access_token_setting_validator"

enabled_site_setting :enable_discourse_github_plugin

after_initialize do
  %w[
    ../app/models/github_commit.rb
    ../app/models/github_repo.rb
    ../app/lib/github_linkback.rb
    ../app/lib/github_badges.rb
    ../app/lib/github_permalinks.rb
    ../app/lib/commits_populator.rb
    ../app/jobs/regular/create_github_linkback.rb
    ../app/jobs/scheduled/grant_github_badges.rb
    ../app/jobs/regular/replace_github_non_permalinks.rb
  ].each { |path| require File.expand_path(path, __FILE__) }

  on(:post_created) do |post|
    if SiteSetting.github_linkback_enabled? && SiteSetting.enable_discourse_github_plugin?
      GithubLinkback.new(post).enqueue
    end
  end

  on(:post_edited) do |post|
    if SiteSetting.github_linkback_enabled? && SiteSetting.enable_discourse_github_plugin?
      GithubLinkback.new(post).enqueue
    end
  end

  on(:before_post_process_cooked) do |doc, post|
    if SiteSetting.github_permalinks_enabled? && SiteSetting.enable_discourse_github_plugin?
      GithubPermalinks.replace_github_non_permalinks(post)
    end
  end
end
