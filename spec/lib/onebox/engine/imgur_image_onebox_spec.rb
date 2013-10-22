require "spec_helper"

describe Onebox::Engine::ImgurImageOnebox do
  before(:all) do
    @link = "http://imgur.com/gallery/twoDTCU"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes image" do
      expect(html).to include("twoDTCU.jpg")
    end
  end
end
