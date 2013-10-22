require "spec_helper"

describe Onebox::Engine::SoundCloudOnebox do
  before(:all) do
    @link = "https://soundcloud.com/rac/penguin-prison-worse-it-gets-rac-mix"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes still" do
      expect(html).to include("artworks-000033643332-vpuznu-t500x500.jpg")
    end

    it "includes description" do
      expect(html).to include("Remix by André Allen Anjos.")
    end

    it "includes embedded video link"
  end
end
