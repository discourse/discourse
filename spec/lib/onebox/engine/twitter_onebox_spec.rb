require "spec_helper"

describe Onebox::Engine::TwitterOnebox do
  before(:all) do
    @link = "https://twitter.com/toastergrrl/status/363116819147538433"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "has tweet text" do
      expect(html).to include("I&#39;m a sucker for pledges.")
    end

    it "has tweet time and date" do
      expect(html).to include("6:59 PM - 1 Aug 13")
    end

    it "has user name" do
      expect(html).to include("@toastergrrl")
    end

    it "has user avatar" do
      expect(html).to include("39b969d32a10b2437563e246708c8f9d_normal.jpeg")
    end

    it "has tweet favorite count" do
      pending
      expect(html).to include("")
    end

    it "has retweet count" do
      pending
      expect(html).to include("")
    end

    it "has URL" do
      expect(html).to include(link)
    end
  end
end
