require 'rails_helper'
require_dependency 'crawler_detection'

describe CrawlerDetection do
  describe "crawler?" do
    it "returns true for crawler user agents" do
      # https://support.google.com/webmasters/answer/1061943?hl=en
      expect(described_class.crawler?("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")).to eq(true)
      expect(described_class.crawler?("Googlebot/2.1 (+http://www.google.com/bot.html)")).to eq(true)
      expect(described_class.crawler?("Googlebot-News")).to eq(true)
      expect(described_class.crawler?("Googlebot-Image/1.0")).to eq(true)
      expect(described_class.crawler?("Googlebot-Video/1.0")).to eq(true)
      expect(described_class.crawler?("(compatible; Googlebot-Mobile/2.1; +http://www.google.com/bot.html)")).to eq(true)
      expect(described_class.crawler?("Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)")).to eq(true)
      expect(described_class.crawler?("(compatible; Mediapartners-Google/2.1; +http://www.google.com/bot.html)")).to eq(true)
      expect(described_class.crawler?("Mediapartners-Google")).to eq(true)
      expect(described_class.crawler?("AdsBot-Google (+http://www.google.com/adsbot.html)")).to eq(true)
      expect(described_class.crawler?("Twitterbot")).to eq(true)
      expect(described_class.crawler?("facebookexternalhit/1.1 (+http(s)://www.facebook.com/externalhit_uatext.php)")).to eq(true)
      expect(described_class.crawler?("Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)")).to eq(true)
      expect(described_class.crawler?("Baiduspider+(+http://www.baidu.com/search/spider.htm)")).to eq(true)
    end

    it "returns false for non-crawler user agents" do
      expect(described_class.crawler?("Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36")).to eq(false)
      expect(described_class.crawler?("Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko")).to eq(false)
      expect(described_class.crawler?("Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Trident/6.0)")).to eq(false)
      expect(described_class.crawler?("Mozilla/5.0 (iPad; CPU OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5355d Safari/8536.25")).to eq(false)
      expect(described_class.crawler?("Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:25.0) Gecko/20100101 Firefox/25.0")).to eq(false)
      expect(described_class.crawler?("Mozilla/5.0 (Linux; U; Android 4.0.3; ko-kr; LG-L160L Build/IML74K) AppleWebkit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30")).to eq(false)
    end

  end
end
