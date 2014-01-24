require "spec_helper"

describe Onebox::Engine::AmazonOnebox do
  before(:all) do
    @link = "http://www.amazon.com/Knit-Noro-Accessories-Colorful-Little/dp/193609620X"
    @uri = "http://www.amazon.com/gp/aw/d/193609620X"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes image" do
      expect(html).to include("img")
    end

    it "includes description" do
      expect(html).to include("Using only the finest natural materials and ecologically sound")
    end

  end
end
