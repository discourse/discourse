require "spec_helper"

describe Onebox::Engine::KinomapOnebox do
  before(:all) do
    @link = "http://www.kinomap.com/watch/52wjcu"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("Enduro Jeunes Touquet - Nicolas Letévé")
    end

    it "returns video photo" do
      expect(html).to include("52wjcu_320x240.jpg")
    end

    it "returns video description" do
      expect(html).to include("A partir du parc moto,")
    end

    it "returns video URL" do
      expect(html).to include("http://v2.kinomap.com/embed/52wjcu")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
