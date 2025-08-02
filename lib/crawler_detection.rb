# frozen_string_literal: true

module CrawlerDetection
  WAYBACK_MACHINE_URL = "archive.org"

  def self.to_matcher(string, type: nil)
    escaped = string.split("|").map { |agent| Regexp.escape(agent) }.join("|")

    if type == :real && Rails.env == "test"
      # we need this bypass so we properly render views
      escaped << "|Rails Testing"
    end

    Regexp.new(escaped, Regexp::IGNORECASE)
  end

  def self.crawler?(user_agent, via_header = nil)
    if user_agent.nil? || user_agent&.include?(WAYBACK_MACHINE_URL) ||
         via_header&.include?(WAYBACK_MACHINE_URL)
      return true
    end

    # this is done to avoid regenerating regexes
    @non_crawler_matchers ||= {}
    @matchers ||= {}

    possibly_real =
      (
        @non_crawler_matchers[SiteSetting.non_crawler_user_agents] ||= to_matcher(
          SiteSetting.non_crawler_user_agents,
          type: :real,
        )
      )

    if user_agent.match?(possibly_real)
      known_bots =
        (@matchers[SiteSetting.crawler_user_agents] ||= to_matcher(SiteSetting.crawler_user_agents))
      if user_agent.match?(known_bots)
        bypass =
          (
            @matchers[SiteSetting.crawler_check_bypass_agents] ||= to_matcher(
              SiteSetting.crawler_check_bypass_agents,
            )
          )
        !user_agent.match?(bypass)
      else
        false
      end
    else
      true
    end
  end

  def self.show_browser_update?(user_agent)
    return false if SiteSetting.browser_update_user_agents.blank?

    @browser_update_matchers ||= {}
    matcher =
      @browser_update_matchers[SiteSetting.browser_update_user_agents] ||= to_matcher(
        SiteSetting.browser_update_user_agents,
      )
    user_agent.match?(matcher)
  end

  # Given a user_agent that returns true from crawler?, should its request be allowed?
  def self.allow_crawler?(user_agent)
    if SiteSetting.allowed_crawler_user_agents.blank? &&
         SiteSetting.blocked_crawler_user_agents.blank?
      return true
    end

    @allowlisted_matchers ||= {}
    @blocklisted_matchers ||= {}

    if SiteSetting.allowed_crawler_user_agents.present?
      allowlisted =
        @allowlisted_matchers[SiteSetting.allowed_crawler_user_agents] ||= to_matcher(
          SiteSetting.allowed_crawler_user_agents,
        )
      !user_agent.nil? && user_agent.match?(allowlisted)
    else
      blocklisted =
        @blocklisted_matchers[SiteSetting.blocked_crawler_user_agents] ||= to_matcher(
          SiteSetting.blocked_crawler_user_agents,
        )
      user_agent.nil? || !user_agent.match?(blocklisted)
    end
  end

  def self.is_blocked_crawler?(user_agent)
    crawler?(user_agent) && !allow_crawler?(user_agent)
  end
end
