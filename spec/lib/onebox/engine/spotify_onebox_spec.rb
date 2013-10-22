require "spec_helper"

describe Onebox::Engine::SpotifyOnebox do
  before(:all) do
    @link = "http://open.spotify.com/album/3eEtlM70GU40OyHMotY15N"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes description" do
      description = "Keep Moving Forward EP, an album by Bubble on Spotify"
      expect(html).to include(description)
    end

    it "includes still" do
      image = "http://o.scdn.co/image/d2c3de070317af4aae4e03daa976690431f1849d"
      expect(html).to include(image)
    end
  end
end
