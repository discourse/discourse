# frozen_string_literal: true

RSpec.describe Onebox::Engine::SpotifyOnebox do
  let(:link) { "https://open.spotify.com/show/5eXZwvvxt3K2dxha3BSaAe" }
  let(:api_link) do
    "https://open.spotify.com/oembed?url=https%3A%2F%2Fopen.spotify.com%2Fshow%2F5eXZwvvxt3K2dxha3BSaAe"
  end
  let(:html) { described_class.new(link).to_html }
  let(:placeholder_html) { described_class.new(link).placeholder_html }

  before { stub_request(:get, api_link).to_return(status: 200, body: onebox_response("spotify")) }

  describe "#placeholder_html" do
    it "returns an image as the placeholder" do
      expect(placeholder_html).to include(
        "https://i.scdn.co/image/ab67656300005f1f3ed9a52396207aad8858a28a",
      )
    end

    it "has a fixed height" do
      expect(placeholder_html).to include("height='300'")
    end
  end

  describe "#to_html" do
    it "returns iframe embed" do
      expect(html).to include(URI(link).path)
      expect(html).to include("iframe")
    end

    it "has object id" do
      expect(html).to include("5eXZwvvxt3K2dxha3BSaAe")
    end

    it "has the a fixed height" do
      expect(html).to include('height="152"')
    end
  end

  describe ".===" do
    it "matches valid Spotify URL" do
      valid_url = URI("https://open.spotify.com/playlist/12345")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Spotify track URL" do
      valid_url = URI("https://open.spotify.com/track/5Hpwb8l7NHJkiCZOPRmfIK?si=24c8d91a5d114c62")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Spotify root URL" do
      valid_root_url = URI("https://open.spotify.com/")
      expect(described_class === valid_root_url).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://open.spotify.com.malicious.com/playlist/12345")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with subdomain" do
      subdomain_url = URI("https://sub.open.spotify.com/playlist/12345")
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match unrelated URL" do
      unrelated_url = URI("https://example.com/open.spotify.com/playlist/12345")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
