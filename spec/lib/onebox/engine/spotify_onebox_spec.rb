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
end
