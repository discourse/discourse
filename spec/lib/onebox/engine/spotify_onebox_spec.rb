require "spec_helper"

describe Onebox::Engine::SpotifyOnebox do
  before(:all) do
    @link = "http://open.spotify.com/album/3eEtlM70GU40OyHMotY15N"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns album title" do
      title = "Keep Moving Forward EP"
      expect(html).to include(title)
    end

    it "returns album description" do
      description = "Keep Moving Forward EP, an album by Bubble on Spotify"
      expect(html).to include(description)
    end

    it "returns album image" do
      image = "http://o.scdn.co/image/d2c3de070317af4aae4e03daa976690431f1849d"
      expect(html).to include(image)
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
