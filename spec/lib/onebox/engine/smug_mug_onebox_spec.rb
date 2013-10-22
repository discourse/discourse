require "spec_helper"

describe Onebox::Engine::SmugMugOnebox do
  before(:all) do
    @link = "http://heyserphoto.smugmug.com/Feathers/Duck-feathers/18516485_5xM7Bj#!i=1179402985&k=kS5HMdV"
    @uri = "https://api.smugmug.com/services/oembed/?url=http%3A%2F%2Fheyserphoto.smugmug.com%2FFeathers%2FDuck-feathers%2F18516485_5xM7Bj%23%21i%3D1179402985%26k%3DkS5HMdV&format=json"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "has author" do
      expect(html).to include("Holly  Heyser")
    end

    it "has caption" do
      expect(html).to include("Tail feather from drake mallard")
    end

    it "has image" do
      expect(html).to include("Mallard_HAH1062-M.jpg")
    end
  end
end
