require "spec_helper"

describe Onebox::Engine::VimeoOnebox do
  before(:all) do
    @link = "http://vimeo.com/70437049"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes iframe" do
      expect(html).to include("iframe")
    end

    it "includes title" do
      expect(html).to include("108 years of Herman Miller in 108 seconds")
    end

    it "includes embedded video link" do
      expect(html).to include("ttp://vimeo.com/moogaloop.swf?clip_id=70437049")
    end
  end
end
