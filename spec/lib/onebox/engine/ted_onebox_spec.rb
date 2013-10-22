require "spec_helper"

describe Onebox::Engine::TedOnebox do
  before(:all) do
    @link = "http://www.ted.com/talks/eli_beer_the_fastest_ambulance_a_motorcycle.html"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes still" do
      expect(html).to include("aa8d0403aec3466d031e3e1c1605637d84d6a07d_389x292.jpg")
    end

    it "includes description" do
      expect(html).to include("As a young EMT on a Jerusalem ambulance")
    end
  end
end
