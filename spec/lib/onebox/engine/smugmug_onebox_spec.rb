require "spec_helper"

describe Onebox::Engine::SmugMugOnebox do
  before(:all) do
    @link = "http://heyserphoto.smugmug.com/Feathers/Duck-feathers/18516485_5xM7Bj#!i=1179402985&k=kS5HMdV"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns the photographer name" do
      expect(html).to include("Holly Heyser")
    end

    it "returns the photo caption" do
      expect(html).to include("Tail feather from drake mallard")
    end

    it "returns the image URL" do
      expect(html).to include("Mallard_HAH1062-M.jpg")
    end

    it "returns the product URL" do
      expect(html).to include(link)
    end
  end
end
