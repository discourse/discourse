module CrawlerDetection
  # added 'ia_archiver' based on https://meta.discourse.org/t/unable-to-archive-discourse-pages-with-the-internet-archive/21232
  # added 'Wayback Save Page' based on https://meta.discourse.org/t/unable-to-archive-discourse-with-the-internet-archive-save-page-now-button/22875
  def self.crawler?(user_agent)
    !/Googlebot|Mediapartners|AdsBot|curl|Twitterbot|facebookexternalhit|bingbot|Baiduspider|ia_archiver|Wayback Save Page/.match(user_agent).nil?
  end
end
