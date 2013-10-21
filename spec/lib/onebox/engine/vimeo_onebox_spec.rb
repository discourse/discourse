require "spec_helper"

describe Onebox::Engine::VimeoOnebox do
  before(:all) do
    @link = "http://vimeo.com/70437049"
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
      expect(html).to include("443673159_1280.jpg")
    end

    it "has description" do
      expect(html).to include("To mark the launch of a new website for Hermann Miller furniture")
    end

    it "has embedded video link" do
      expect(html).to include("http://vimeo.com/moogaloop.swf?clip_id=70437049")
    end
  end
end
