require "spec_helper"

describe Onebox::Engine::KinomapOnebox do
  before(:all) do
    @link = "http://www.kinomap.com/watch/52wjcu"
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
      expect(html).to include("52wjcu_320x240.jpg")
    end

    it "has description" do
      expect(html).to include("A partir du parc moto,")
    end

    it "has embedded video link" do
      expect(html).to include("http://v2.kinomap.com/embed/52wjcu")
    end
  end
end
