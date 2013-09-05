require "spec_helper"

describe Onebox::Engine::SlideshareOnebox do
  let(:link) { "http://slideshare.net" }
  before do
    fake(link, response("slideshare.response"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns presentation title" do
      expect(html).to include("12 Local Traditions That")
    end

    it "returns presentation description" do
      expect(html).to include("12 Local traditions that will make")
    end

    it "returns presentation image" do
      expect(html).to include("12localtraditions-130729070157-phpapp01-thumbnail-4")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
