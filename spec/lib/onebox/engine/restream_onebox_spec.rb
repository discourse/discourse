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
    it "is registered so the matcher selects it for a player URL" do
      options = {
        allowed_iframe_regexes:
          Onebox::Engine.origins_to_regexes(Onebox::Engine.all_iframe_origins),
      }

      expect(Onebox::Matcher.new("https://player.restream.io/?token=abc", options).oneboxed).to eq(
        described_class,
      )
    end

    it "renders the player iframe in the sanitized onebox output" do
      html = Onebox.preview("https://player.restream.io/?token=abc").to_s

      expect(html).to include('class="restream-onebox"')
      expect(html).to include('src="https://player.restream.io/?token=abc"')
      expect(html).to include("allowfullscreen")
      # The core onebox sanitizer does not permit the `allow` attribute, so
      # autoplay delegation is intentionally not emitted
      expect(html).not_to include("autoplay")
    end
  end
end
