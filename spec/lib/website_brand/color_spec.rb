# frozen_string_literal: true

RSpec.describe WebsiteBrand::Color do
  describe ".parse" do
    it "reads hex, named, rgb, hsl and modern color functions" do
      {
        "#E8590C" => "e8590c",
        "#fa0" => "ffaa00",
        "#e8590cff" => "e8590c",
        "white" => "ffffff",
        "rgb(232, 89, 12)" => "e8590c",
        "rgb(232 89 12 / 100%)" => "e8590c",
        "rgb(100% 0% 0%)" => "ff0000",
        "hsl(210 100% 40%)" => "0066cc",
        "hsla(210, 100%, 40%, 1)" => "0066cc",
        "hsl(0.5turn 100% 40%)" => "00cccc",
        "oklch(62.3% 0.214 259.815)" => "2b7fff",
        "oklab(0.623 -0.0378 -0.2106)" => "2b7fff",
        "lab(50% 40 59.5)" => "bf5700",
        "lch(52.2% 72.2 50)" => "cd561a",
        "color(srgb 1 0 0)" => "ff0000",
        "color(display-p3 0% 50% 100%)" => "0080ff",
        "light-dark(#111111, #eeeeee)" => "111111",
        "#e8590c !important" => "e8590c",
      }.each { |value, hex| expect(described_class.parse(value)).to eq(hex), value }
    end

    it "ignores values that aren't opaque colors" do
      [
        "#e8590c80",
        "rgba(0, 0, 0, 0.5)",
        "transparent",
        "currentColor",
        "inherit",
        "",
        nil,
      ].each { |value| expect(described_class.parse(value)).to be_nil, value.inspect }
    end

    it "resolves custom properties, including fallbacks and color channels" do
      variables = { "--brand" => "#635BFF", "--channels" => "59 130 246", "--opacity" => "1" }

      expect(described_class.parse("var(--brand)", variables)).to eq("635bff")
      expect(described_class.parse("var(--missing, #e8590c)", variables)).to eq("e8590c")
      expect(described_class.parse("rgb(var(--channels) / var(--opacity))", variables)).to eq(
        "3b82f6",
      )
    end

    it "gives up on custom properties that can't be resolved" do
      variables = { "--loop" => "var(--loop)" }

      expect(described_class.parse("var(--missing)", variables)).to be_nil
      expect(described_class.parse("var(--loop)", variables)).to be_nil
    end
  end

  describe ".first_in" do
    it "finds the first color in a shorthand or a gradient" do
      expect(described_class.first_in("url(texture.png) no-repeat #e8590c")).to eq("e8590c")
      expect(
        described_class.first_in(
          "linear-gradient(90deg, light-dark(rgb(1 2 3), #000) 0%, #fff 100%)",
        ),
      ).to eq("010203")
      expect(described_class.first_in("none")).to be_nil
    end
  end

  describe ".vivid?" do
    it "only accepts colors that can carry a brand" do
      expect(described_class.vivid?("e8590c")).to eq(true)
      expect(%w[777777 fdfdfd 050505].map { |hex| described_class.vivid?(hex) }).to all(eq(false))
    end
  end
end
