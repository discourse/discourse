# frozen_string_literal: true

module CrawlerDetection
  WAYBACK_MACHINE_URL = "web.archive.org"

  def self.to_matcher(string, type: nil)
    escaped = string.split('|').map { |agent| Regexp.escape(agent) }.join('|')

    if type == :real && Rails.env == "test"
      # we need this bypass so we properly render views
      escaped << "|Rails Testing"
    end

    Regexp.new(escaped, Regexp::IGNORECASE)
  end

  def self.crawler?(user_agent, via_header = nil)
    return true if user_agent.nil? || via_header&.include?(WAYBACK_MACHINE_URL)

    # this is done to avoid regenerating regexes
    @non_crawler_matchers ||= {}
    @matchers ||= {}

    possibly_real = (@non_crawler_matchers[SiteSetting.non_crawler_user_agents] ||= to_matcher(SiteSetting.non_crawler_user_agents, type: :real))

    if user_agent.match?(possibly_real)
      known_bots = (@matchers[SiteSetting.crawler_user_agents] ||= to_matcher(SiteSetting.crawler_user_agents))
      if user_agent.match?(known_bots)
        bypass = (@matchers[SiteSetting.crawler_check_bypass_agents] ||= to_matcher(SiteSetting.crawler_check_bypass_agents))
        !user_agent.match?(bypass)
      else
        false
      end
    else
      true
    end

  end

  # Given a user_agent that returns true from crawler?, should its request be allowed?
  def self.allow_crawler?(user_agent)
    return true if SiteSetting.whitelisted_crawler_user_agents.blank? &&
      SiteSetting.blacklisted_crawler_user_agents.blank?

    @whitelisted_matchers ||= {}
    @blacklisted_matchers ||= {}

    if SiteSetting.whitelisted_crawler_user_agents.present?
      whitelisted = @whitelisted_matchers[SiteSetting.whitelisted_crawler_user_agents] ||= to_matcher(SiteSetting.whitelisted_crawler_user_agents)
      !user_agent.nil? && user_agent.match?(whitelisted)
    else
      blacklisted = @blacklisted_matchers[SiteSetting.blacklisted_crawler_user_agents] ||= to_matcher(SiteSetting.blacklisted_crawler_user_agents)
      user_agent.nil? || !user_agent.match?(blacklisted)
    end
  end

  def self.is_blocked_crawler?(user_agent)
    crawler?(user_agent) && !allow_crawler?(user_agent)
  end
end
