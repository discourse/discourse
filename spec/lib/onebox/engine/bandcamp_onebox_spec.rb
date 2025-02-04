# frozen_string_literal: true

RSpec.describe Onebox::Engine::BandCampOnebox do
  describe ".===" do
    it "matches valid Bandcamp album URL" do
      valid_url_album = URI("https://artist.bandcamp.com/album/some-album")
      expect(described_class === valid_url_album).to eq(true)
    end

    it "matches valid Bandcamp track URL" do
      valid_url_track = URI("https://artist.bandcamp.com/track/some-track")
      expect(described_class === valid_url_track).to eq(true)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://artist.bandcamp.com/playlist/some-playlist")
      expect(described_class === invalid_path_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/album/some-album")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
