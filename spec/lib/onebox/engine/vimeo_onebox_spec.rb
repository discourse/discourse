require "spec_helper"

describe Onebox::Engine::VimeoOnebox do
  before(:all) do
    @link = "http://vimeo.com/70437049"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes still" do
      expect(html).to include("443673159_1280.jpg")
    end

    it "includes description" do
      expect(html).to include("To mark the launch of a new website for Hermann Miller furniture")
    end

    it "includes embedded video link" do
      expect(html).to include("http://vimeo.com/moogaloop.swf?clip_id=70437049")
    end
  end
end
