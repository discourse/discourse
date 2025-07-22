# frozen_string_literal: true

module Jobs
  class CreateGithubLinkback < ::Jobs::Base
    def execute(args)
      return unless SiteSetting.enable_discourse_github_plugin?
      return unless SiteSetting.github_linkback_enabled?
      return if (post = Post.find_by_id(args[:post_id])).blank?
      GithubLinkback.new(post).create
    end
  end
end
