require "spec_helper"

describe Onebox::Engine::BliptvOnebox do
  before(:all) do
    @link = "http://blip.tv/day9tv/sc2l-week-3-axiom-vs-acer-g6-6623829"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes image" do
      expect(html).to include("Striderdoom-SC2LWeek3AxiomVsAcerG6178-416.jpg")
    end

    it "includes video description" do
      expect(html).to include("Acer and Axiom go head to head in week 3!")
    end

    it "includes embedded video link" do
      expect(html).to include("http://blip.tv/day9tv/sc2l-week-3-axiom-vs-acer-g6-6623829")
    end
  end
end
