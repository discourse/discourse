require 'rails_helper'
require 'browser_detection'

describe BrowserDetection do

  it "detects browser, device and operating system" do
    [
      ["Mozilla/4.0 (compatible; MSIE 9.0; Windows NT 6.1)", :ie, :windows, :windows],
      ["Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; WOW64; Trident/6.0)", :ie, :windows, :windows],
      ["Mozilla/5.0 (iPad; CPU OS 9_3_2 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13F69 Safari/601.1", :safari, :ipad, :ios],
      ["Mozilla/5.0 (iPhone; CPU iPhone OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B143 Safari/601.1", :safari, :iphone, :ios],
      ["Mozilla/5.0 (iPhone; CPU iPhone OS 9_3_2 like Mac OS X) AppleWebKit/601.1 (KHTML, like Gecko) CriOS/51.0.2704.104 Mobile/13F69 Safari/601.1.46", :chrome, :iphone, :ios],
      ["Mozilla/5.0 (Linux; Android 4.1.1; Nexus 7 Build/JRO03D) AppleWebKit/535.19 (KHTML, like Gecko) Chrome/18.0.1025.166 Safari/535.19", :chrome, :android, :android],
      ["Mozilla/5.0 (Linux; Android 4.4.2; XMP-6250 Build/HAWK) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/30.0.0.0 Safari/537.36 ADAPI/2.0 (UUID:9e7df0ed-2a5c-4a19-bec7-2cc54800f99d) RK3188-ADAPI/1.2.84.533 (MODEL:XMP-6250)", :chrome, :android, :android],
      ["Mozilla/5.0 (Linux; Android 5.1; Nexus 7 Build/LMY47O) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.105 Safari/537.36", :chrome, :android, :android],
      ["Mozilla/5.0 (Linux; Android 6.0.1; vivo 1603 Build/MMB29M) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.83 Mobile Safari/537.36", :chrome, :android, :android],
      ["Mozilla/5.0 (Linux; Android; 4.1.2; GT-I9100 Build/000000) AppleWebKit/537.22 (KHTML, like Gecko) Chrome/25.0.1234.12 Mobile Safari/537.22 OPR/14.0.123.123", :opera, :android, :android],
      ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10.12; rv:54.0) Gecko/20100101 Firefox/54.0", :firefox, :mac, :macos],
      ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10.12; rv:54.0) Gecko/20100101 Firefox/54.0", :firefox, :mac, :macos],
      ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.90 Safari/537.36", :chrome, :mac, :macos],
      ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.113 Safari/537.36", :chrome, :windows, :windows],
      ["Mozilla/5.0 (Windows NT 5.1; rv:7.0.1) Gecko/20100101 Firefox/7.0.1", :firefox, :windows, :windows],
      ["Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko", :ie, :windows, :windows],
      ["Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.90 Safari/537.36", :chrome, :windows, :windows],
      ["Mozilla/5.0 (Windows NT 6.1; WOW64; rv:40.0) Gecko/20100101 Firefox/40.1", :firefox, :windows, :windows],
      ["Mozilla/5.0 (Windows NT 6.1; WOW64; rv:54.0) Gecko/20100101 Firefox/54.0", :firefox, :windows, :windows],
      ["Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/44.0.2403.157 Safari/537.36", :chrome, :linux, :linux],
      ["Mozilla/5.0 (X11; Linux x86_64; rv:10.0) Gecko/20150101 Firefox/47.0 (Chrome)", :firefox, :linux, :linux],
      ["Opera/9.80 (X11; Linux zvav; U; en) Presto/2.12.423 Version/12.16", :opera, :linux, :linux],
      ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.135 Safari/537.36 Edge/12.246", :edge, :windows, :windows],
    ].each do |user_agent, browser, device, os|
      expect(BrowserDetection.browser(user_agent)).to eq(browser)
      expect(BrowserDetection.device(user_agent)).to eq(device)
      expect(BrowserDetection.os(user_agent)).to eq(os)
    end
  end

end
