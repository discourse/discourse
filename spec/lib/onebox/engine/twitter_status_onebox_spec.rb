require "spec_helper"

describe Onebox::Engine::TwitterStatusOnebox do
  before(:all) do
    @link = "https://twitter.com/discourse/status/504354595733504000"
    @uri = "https://api.twitter.com/1/statuses/oembed.json?id=504354595733504000"
    fake(@uri, response(described_class.onebox_name))
    onebox = described_class.new(@link)
    @html = onebox.to_html
  end
  let(:html) { @html }

  describe "#to_html" do
    it "includes tweet" do
      expect(html).to include("Introducing Discourse 1.0!")
    end

    it "includes timestamp" do
      pending
      expect(html).to include("August 26, 2014")
    end

    it "includes username" do
      expect(html).to include("discourse")
    end

    it "includes link" do
      expect(html).to include("https://twitter.com/discourse/statuses/504354595733504000")
    end
  end
end
