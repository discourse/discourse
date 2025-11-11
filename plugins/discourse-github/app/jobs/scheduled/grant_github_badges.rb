# frozen_string_literal: true

module DiscourseGithubPlugin
  class UpdateJob < ::Jobs::Scheduled
    every 4.hours

    def execute(args)
      return unless SiteSetting.enable_discourse_github_plugin?
      return unless SiteSetting.github_badges_enabled?
      return if SiteSetting.github_linkback_access_token.blank?

      GithubRepo.repos.each { |repo| CommitsPopulator.new(repo).populate! }
      GithubBadges.grant!
    end
  end
end
