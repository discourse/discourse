# frozen_string_literal: true

RSpec.describe Onebox::Engine::FacebookMediaOnebox do
  describe "regex URI match" do
    it "matches videos with title" do
      expect(match("https://www.facebook.com/user/videos/title/123456789/")).to eq true
    end

    it "matches videos without a title" do
      expect(match("https://facebook.com/user/videos/123456789")).to eq true
    end

    it "only matches the facebook.com domain" do
      expect(match("https://somedomain.com/a.facebook.com/a/videos")).to eq false
    end

    def match(url)
      Onebox::Engine::FacebookMediaOnebox === URI(url)
    end
  end
end
