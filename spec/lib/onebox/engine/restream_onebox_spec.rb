# frozen_string_literal: true

RSpec.describe Onebox::Engine::RestreamOnebox do
  describe ".===" do
    it "matches a tokenized player URL" do
      url = URI("https://player.restream.io/?token=624a83cddea44b6788cc52b38ce78748")
      expect(described_class === url).to eq(true)
    end

    it "matches the bare player URL" do
      url = URI("https://player.restream.io/")
      expect(described_class === url).to eq(true)
    end

    it "does not match a path on the player host" do
      url = URI("https://player.restream.io/some/path")
      expect(described_class === url).to eq(false)
    end

    it "does not match an unrelated host" do
      url = URI("https://restream.io/")
      expect(described_class === url).to eq(false)
    end

    it "does not treat a lookalike host as the player" do
      url = URI("https://player.restream.io.evil.example/?token=x")
      expect(described_class === url).to eq(false)
    end
  end

  describe "iframe origin" do
    it "allowlists the player origin so Discourse keeps the iframe" do
      expect(Onebox::Engine.all_iframe_origins).to include("https://player.restream.io")
    end
  end

  describe "#to_html" do
    it "emits the player iframe pointing at the original URL" do
      html = described_class.new("https://player.restream.io/?token=abc").to_html

      expect(html).to include('class="restream-onebox"')
      expect(html).to include('src="https://player.restream.io/?token=abc"')
      expect(html).to include("allowfullscreen")
      expect(html).to include('allow="autoplay"')
    end
  end
end
