require "spec_helper"

describe Onebox::Engine::SmugMugOnebox do
  before(:all) do
    @link = "http://heyserphoto.smugmug.com/Feathers/Duck-feathers/18516485_5xM7Bj#!i=1179402985&k=kS5HMdV"
    api = "https://api.smugmug.com/services/oembed/?url=http%3A%2F%2Fheyserphoto.smugmug.com%2FFeathers%2FDuck-feathers%2F18516485_5xM7Bj%23%21i%3D1179402985%26k%3DkS5HMdV&format=json"
    fake(api, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns the photographer name" do
      expect(html).to include("Holly  Heyser")
    end

    it "returns the photo caption" do
      expect(html).to include("Tail feather from drake mallard")
    end

    it "returns the image URL" do
      expect(html).to include("Mallard_HAH1062-M.jpg")
    end

    it "returns the URL" do
      expect(html).to include(link)
    end
  end
end
