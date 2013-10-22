require "spec_helper"

describe Onebox::Engine::TwitterOnebox do
  before(:all) do
    @link = "https://twitter.com/toastergrrl/status/363116819147538433"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes tweet" do
      expect(html).to include("I&#39;m a sucker for pledges.")
    end

    it "includes timestamp" do
      expect(html).to include("6:59 PM - 1 Aug 13")
    end

    it "includes username" do
      expect(html).to include("@toastergrrl")
    end

    it "includes user avatar" do
      expect(html).to include("39b969d32a10b2437563e246708c8f9d_normal.jpeg")
    end

    it "includes tweet favorite count" do
      pending
      expect(html).to include("")
    end

    it "includes retweet count" do
      pending
      expect(html).to include("")
    end
  end
end
