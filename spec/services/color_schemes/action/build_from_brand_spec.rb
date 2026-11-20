# frozen_string_literal: true

RSpec.describe ColorSchemes::Action::BuildFromBrand do
  describe ".call" do
    def contrast(palette, foreground, background)
      ColorMath.contrast_ratio(palette[foreground], palette[background])
    end

    def hue(color)
      ColorMath::Converters.rgb_to_hsl(*ColorMath::Converters.hex_to_rgb(color)).first
    end

    def grey?(color)
      ColorMath::Converters.hex_to_rgb(color).uniq.one?
    end

    it "builds every palette color and uses a readable brand color for links and buttons" do
      result = described_class.call(brand: "#635bff")

      expect(result.light.keys).to match_array(ColorScheme.base_colors.keys)
      expect(result.dark.keys).to match_array(ColorScheme.base_colors.keys)
      expect(result.light).to include("secondary" => "ffffff", "tertiary" => "635bff")
      expect(result.adjustments.map(&:mode)).not_to include(:light)
    end

    it "keeps core's status colors, and replaces quaternary only with an accent" do
      light_defaults = ColorScheme.base_colors.slice(*%w[highlight danger success love])
      dark_defaults = ColorScheme::BUILT_IN_SCHEMES[:Dark].slice(*%w[highlight danger success love])

      result = described_class.call(brand: "635bff")
      with_accent = described_class.call(brand: "635bff", accent: "#FF7A00")

      expect(result.light).to include(light_defaults.merge("success" => "009900"))
      expect(result.dark).to include(dark_defaults)
      expect([result.light["quaternary"], result.dark["quaternary"]]).to eq(%w[e45735 c14924])
      expect([with_accent.light["quaternary"], with_accent.dark["quaternary"]]).to eq(
        %w[ff7a00 ff7a00],
      )
    end

    it "darkens a light brand color until links are readable, keeping its hue, and reports it" do
      result = described_class.call(brand: "ffcc00")
      link = result.light["tertiary"]

      expect(link).not_to eq("ffcc00")
      expect(contrast(result.light, "tertiary", "secondary")).to be >= 4.5
      expect(hue(link)).to be_within(1).of(hue("ffcc00"))
      expect(result.adjustments).to contain_exactly(
        described_class::Adjustment.new(
          mode: :light,
          name: "tertiary",
          from: "ffcc00",
          to: link,
          against: "ffffff",
        ),
      )
    end

    it "lightens a dark brand color for the dark palette" do
      result = described_class.call(brand: "1a237e")

      expect(result.light["tertiary"]).to eq("1a237e")
      expect(ColorMath.relative_luminance(result.dark["tertiary"])).to be >
        ColorMath.relative_luminance("1a237e")
      expect(contrast(result.dark, "tertiary", "secondary")).to be >= 4.5
      expect(result.adjustments.map { |adjustment| [adjustment.mode, adjustment.name] }).to eq(
        [[:dark, "tertiary"]],
      )
    end

    it "keeps a readable header color and moves one that no text can read" do
      readable = described_class.call(brand: "635bff", header: "0a2540")
      mid_tone = described_class.call(brand: "635bff", header: "ea2983")

      expect(readable.light).to include(
        "header_background" => "0a2540",
        "header_primary" => "ffffff",
      )
      expect(mid_tone.light["header_background"]).not_to eq("ea2983")
      expect(contrast(mid_tone.light, "header_primary", "header_background")).to be >= 4.5
      expect(mid_tone.adjustments.map(&:name)).to include("header_background")
    end

    it "keeps text and backgrounds neutral for a grey brand color" do
      result = described_class.call(brand: "333")

      expect([result.light["primary"], result.dark["primary"], result.dark["secondary"]]).to all(
        satisfy { |color| grey?(color) },
      )
    end

    it "keeps text readable in both palettes for any brand colors" do
      random = Random.new(2026)
      color = -> { format("%06x", random.rand(0x1000000)) }

      200.times do
        options = {
          brand: color.call,
          accent: color.call,
          header: [color.call, nil].sample(random:),
        }
        result = described_class.call(**options)

        { light: result.light, dark: result.dark }.each do |mode, palette|
          expect(palette.values).to all(match(/\A\h{6}\z/))
          described_class::READABLE_PAIRS.each do |foreground, background|
            expect(contrast(palette, foreground, background)).to be >= 4.5,
            "#{foreground} on #{background} in #{mode} mode is unreadable for #{options}"
          end
        end
      end
    end

    it "accepts colors with or without a hash, in any case and in short form" do
      expect(described_class.call(brand: "#FC0", header: "#0A2540")).to eq(
        described_class.call(brand: "ffcc00", header: "0a2540"),
      )
    end

    it "rejects values that aren't hex colors" do
      expect { described_class.call(brand: "red") }.to raise_error(ArgumentError)
      expect { described_class.call(brand: "635bff", header: "#12345") }.to raise_error(
        ArgumentError,
      )
    end
  end
end
