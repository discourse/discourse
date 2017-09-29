module CrawlerDetection

  # added 'ia_archiver' based on https://meta.discourse.org/t/unable-to-archive-discourse-pages-with-the-internet-archive/21232
  # added 'Wayback Save Page' based on https://meta.discourse.org/t/unable-to-archive-discourse-with-the-internet-archive-save-page-now-button/22875
  # added 'Swiftbot' based on https://meta.discourse.org/t/how-to-add-html-markup-or-meta-tags-for-external-search-engine/28220
  def self.to_matcher(string)
    escaped = string.split('|').map { |agent| Regexp.escape(agent) }.join('|')
    Regexp.new(escaped)
  end

  def self.crawler?(user_agent)
    # this is done to avoid regenerating regexes
    @matchers ||= {}
    matcher = (@matchers[SiteSetting.crawler_user_agents] ||= to_matcher(SiteSetting.crawler_user_agents))
    matcher.match?(user_agent)
  end
end
