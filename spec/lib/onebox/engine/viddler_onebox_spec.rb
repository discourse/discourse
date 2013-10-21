require "spec_helper"

describe Onebox::Engine::ViddlerOnebox do
  before(:all) do
    @link = "http://www.viddler.com/v/7164f749"
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
      expect(html).to include("thumbnail_2_7164f749_v2.jpg")
    end

    it "has description" do
      expect(html).to include("Get familiar with your Viddler account.")
    end

    it "has embedded video link" do
      expect(html).to include("http://www.viddler.com/player/7164f749")
    end

    it "returns video embed code"
  end
end
