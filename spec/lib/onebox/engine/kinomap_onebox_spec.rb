require "spec_helper"

describe Onebox::Engine::KinomapOnebox do
  before(:all) do
    @link = "http://www.kinomap.com/watch/52wjcu"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes still" do
      expect(html).to include("52wjcu_320x240.jpg")
    end

    it "includes description" do
      expect(html).to include("A partir du parc moto,")
    end

    it "includes embedded video link" do
      expect(html).to include("http://v2.kinomap.com/embed/52wjcu")
    end
  end
end
