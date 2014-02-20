module CrawlerDetection
  def self.crawler?(user_agent)
    !/Googlebot|Mediapartners|AdsBot/.match(user_agent).nil?
  end
end
