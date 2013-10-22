require "spec_helper"

describe Onebox::Engine::ItunesOnebox do
  before(:all) do
    @link = "https://itunes.apple.com/us/app/minecraft-pocket-edition/id479516143?mt=8"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes image" do
      expect(html).to include("bxerxqln.png")
    end

    it "includes description" do
      expect(html).to include("Get Minecraft – Pocket Edition on the App Store.")
    end
  end
end
