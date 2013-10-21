require "spec_helper"

describe Onebox::Engine::ClikThroughOnebox do
  before(:all) do
    @link = "http://www.clikthrough.com/theater/video/49/en-US"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes video description" do
      expect(html).to include("Keri Hilson gets taken down by love once again")
    end
  end
end
