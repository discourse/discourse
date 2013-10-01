require "spec_helper"

describe Onebox::Engine::ItunesOnebox do
  before(:all) do
    @link = "https://itunes.apple.com/us/app/minecraft-pocket-edition/id479516143?mt=8"
    fake(@link, response("itunes"))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns the product title" do
      expect(html).to include("Minecraft – Pocket Edition")
    end

    it "returns the product image" do
      expect(html).to include("bxerxqln.175x175-75.jpg")
    end

    it "returns the product description" do
      expect(html).to include("Minecraft — Pocket Edition is a Universal App!")
    end
  end
end
