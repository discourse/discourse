module CrawlerDetection
  def self.crawler?(user_agent)
    !/Googlebot|Mediapartners|AdsBot|curl|Twitterbot|facebookexternalhit|bingbot|Baiduspider/.match(user_agent).nil?
  end
end
