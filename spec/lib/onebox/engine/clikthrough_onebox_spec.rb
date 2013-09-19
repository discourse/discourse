require "spec_helper"

describe Onebox::Engine::ClikThroughOnebox do
  let(:link) { "http://www.clikthrough.com/theater/video/49/en-US" }

  before do
    fake(link, response("clikthrough"))
  end

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("Keri Hilson - Knock You Down")
    end

    it "returns video description" do
      expect(html).to include("Keri Hilson gets taken down by love once again")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
