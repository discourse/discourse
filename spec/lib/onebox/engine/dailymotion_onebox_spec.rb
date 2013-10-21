require "spec_helper"

describe Onebox::Engine::DailymotionOnebox do
  before(:all) do
    @link = "http://dailymotion.com"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "has still" do
      expect(html).to include("526x297-bxE.jpg")
    end

    it "has description" do
      expect(html).to include("Vibrez au son de l&#39;electro-pop des Irlandais de Two Door Cinema Club,")
    end

    it "has embedded video link" do
      expect(html).to include("http://www.dailymotion.com/swf/video/x12h020?autoPlay=1")
    end

    it "has embed code"
  end
end
