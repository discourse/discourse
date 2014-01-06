require "spec_helper"

describe Onebox::Engine::ClikThroughOnebox do
  before(:all) do
    @link = "http://www.clikthrough.com/theater/video/49/en-US"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes video description" do
      expect(html).to include("Keri Hilson gets taken down by love once again")
    end
  end
end
