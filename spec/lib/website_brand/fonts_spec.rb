# frozen_string_literal: true

RSpec.describe WebsiteBrand::Fonts do
  describe ".match" do
    def match(stack)
      described_class.match(stack)&.to_h
    end

    it "matches the first font in a stack to a Discourse font" do
      expect(match('"Open Sans", Arial, sans-serif')).to eq(key: "open_sans", exact: true)
      expect(match("Noto Sans JP, sans-serif")).to eq(key: "noto_sans_jp", exact: true)
      expect(match("Roboto Condensed")).to eq(key: "roboto_condensed", exact: true)
    end

    it "recognizes the names that font loaders give a font" do
      expect(match("Inter Variable, sans-serif")).to eq(key: "inter", exact: true)
      expect(match("'__Inter_d65c78', '__Inter_Fallback_d65c78'")).to eq(key: "inter", exact: true)
      expect(match('"Helvetica Neue", Helvetica')).to eq(key: "helvetica", exact: true)
    end

    it "matches system font stacks to the system font" do
      expect(match("-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto")).to eq(
        key: "system",
        exact: true,
      )
    end

    it "picks the closest font for its generic family when Discourse doesn't offer it" do
      expect(match("Söhne, Helvetica Neue, sans-serif")).to eq(
        key: SiteSetting.defaults[:base_font],
        exact: false,
      )
      expect(match("Interface, sans-serif")).to eq(
        key: SiteSetting.defaults[:base_font],
        exact: false,
      )
      expect(match("Georgia, 'Times New Roman', serif")).to eq(key: "merriweather", exact: false)
      expect(match("Menlo, monospace")).to eq(key: "jet_brains_mono", exact: false)
    end

    it "returns nil for an empty stack" do
      expect(match("")).to be_nil
      expect(match(nil)).to be_nil
    end
  end
end
