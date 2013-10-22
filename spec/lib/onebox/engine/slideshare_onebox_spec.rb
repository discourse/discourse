require "spec_helper"

describe Onebox::Engine::SlideshareOnebox do
  before(:all) do
    @link = "http://www.slideshare.net/TravelWorldPassport/12-local-traditions"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes description" do
      expect(html).to include("12 Local traditions that will make")
    end

    it "includes still" do
      expect(html).to include("12localtraditions-130729070157-phpapp01-thumbnail-4")
    end
  end
end
