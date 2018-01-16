module CrawlerDetection

  def self.to_matcher(string)
    escaped = string.split('|').map { |agent| Regexp.escape(agent) }.join('|')
    Regexp.new(escaped, Regexp::IGNORECASE)
  end

  def self.crawler?(user_agent)
    # this is done to avoid regenerating regexes
    @non_crawler_matchers ||= {}
    @matchers ||= {}

    possibly_real = (@non_crawler_matchers[SiteSetting.non_crawler_user_agents] ||= to_matcher(SiteSetting.non_crawler_user_agents))

    if user_agent.match?(possibly_real)
      known_bots = (@matchers[SiteSetting.crawler_user_agents] ||= to_matcher(SiteSetting.crawler_user_agents))
      user_agent.match?(known_bots)
    else
      true
    end

  end
end
