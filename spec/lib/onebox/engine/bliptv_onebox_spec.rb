require "spec_helper"

describe Onebox::Engine::BliptvOnebox do
  before(:all) do
    @link = "http://blip.tv"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("SC2L Week 3 - Axiom vs Acer G6")
    end

    it "returns image" do
      expect(html).to include("Striderdoom-SC2LWeek3AxiomVsAcerG6178-416.jpg")
    end

    it "returns video description" do
      expect(html).to include("Acer and Axiom go head to head in week 3!")
    end

    it "returns video" do
      expect(html).to include("http://blip.tv/day9tv/sc2l-week-3-axiom-vs-acer-g6-6623829")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
