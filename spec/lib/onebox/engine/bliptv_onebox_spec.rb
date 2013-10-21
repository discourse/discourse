require "spec_helper"

describe Onebox::Engine::BliptvOnebox do
  before(:all) do
    @link = "http://blip.tv/day9tv/sc2l-week-3-axiom-vs-acer-g6-6623829"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "has image" do
      expect(html).to include("Striderdoom-SC2LWeek3AxiomVsAcerG6178-416.jpg")
    end

    it "has video description" do
      expect(html).to include("Acer and Axiom go head to head in week 3!")
    end

    it "has embedded video link" do
      expect(html).to include("http://blip.tv/day9tv/sc2l-week-3-axiom-vs-acer-g6-6623829")
    end
  end
end
