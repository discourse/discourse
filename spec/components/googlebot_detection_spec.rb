require 'spec_helper'
require_dependency 'googlebot_detection'

describe GooglebotDetection do
  describe "googlebot?" do
    it "returns true for googlebot user agents" do
      # https://support.google.com/webmasters/answer/1061943?hl=en
      described_class.googlebot?("Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)").should == true
      described_class.googlebot?("Googlebot/2.1 (+http://www.google.com/bot.html)").should == true
      described_class.googlebot?("Googlebot-News").should == true
      described_class.googlebot?("Googlebot-Image/1.0").should == true
      described_class.googlebot?("Googlebot-Video/1.0").should == true
      described_class.googlebot?("(compatible; Googlebot-Mobile/2.1; +http://www.google.com/bot.html)").should == true
      described_class.googlebot?("Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)").should == true
      described_class.googlebot?("(compatible; Mediapartners-Google/2.1; +http://www.google.com/bot.html)").should == true
      described_class.googlebot?("Mediapartners-Google").should == true
      described_class.googlebot?("AdsBot-Google (+http://www.google.com/adsbot.html)").should == true
    end

    it "returns false for non-googlebot user agents" do
      described_class.googlebot?("Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1667.0 Safari/537.36").should == false
      described_class.googlebot?("Mozilla/5.0 (Windows NT 6.3; Trident/7.0; rv:11.0) like Gecko").should == false
      described_class.googlebot?("Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Trident/6.0)").should == false
      described_class.googlebot?("Mozilla/5.0 (iPad; CPU OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5355d Safari/8536.25").should == false
      described_class.googlebot?("Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:25.0) Gecko/20100101 Firefox/25.0").should == false
      described_class.googlebot?("Mozilla/5.0 (Linux; U; Android 4.0.3; ko-kr; LG-L160L Build/IML74K) AppleWebkit/534.30 (KHTML, like Gecko) Version/4.0 Mobile Safari/534.30").should == false
    end

  end
end
