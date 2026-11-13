# frozen_string_literal: true

RSpec.describe AppearanceStyles::PaletteColors do
  # Sass writes compiled colors as hex or as rgb() with percentages.
  def compiled_colors(color_scheme)
    css, = Stylesheet::Compiler.compile_asset(:color_definitions, color_scheme_id: color_scheme&.id)
    hex = css.scan(/(--[\w-]+):\s*#(\h{6}|\h{3});/).to_h
    percentages =
      css
        .scan(/(--[\w-]+):\s*rgb\(([\d.]+)%,\s*([\d.]+)%,\s*([\d.]+)%\);/)
        .to_h do |name, *channels|
          [name, ColorMath::Converters.rgb_to_hex(channels.map { |c| (c.to_f * 2.55).round })]
        end
    hex.merge(percentages)
  end

  def channel_distance(hex, other_hex)
    ColorMath::Converters
      .hex_to_rgb(hex)
      .zip(ColorMath::Converters.hex_to_rgb(other_hex))
      .map { |a, b| (a - b).abs }
      .max
  end

  def expect_matches_compiled(palette, color_scheme)
    compiled = compiled_colors(color_scheme)
    variables =
      described_class::DIFFS.keys + described_class::HEADER_BLENDS.keys +
        described_class::CHOICES.keys
    checked = variables & compiled.keys

    expect(checked.size).to be > 50
    checked.each do |variable|
      expect(channel_distance(palette[variable], described_class.normalize(compiled[variable]))).to(
        be <= 3,
        "#{variable}: #{palette[variable]} vs compiled #{compiled[variable]}",
      )
    end
  end

  it "matches the shades core compiles for its default palette" do
    expect_matches_compiled(described_class.new(ColorScheme.base_colors), nil)
  end

  it "matches the shades core compiles for a dark palette" do
    dark =
      ColorScheme.create!(
        name: "Dark test",
        colors: ColorScheme::BUILT_IN_SCHEMES[:Dark].map { |name, hex| { name:, hex: } },
      )
    expect_matches_compiled(described_class.new(ColorScheme::BUILT_IN_SCHEMES[:Dark]), dark)
  end

  it "uses a shade the palette sets itself" do
    palette = described_class.new("primary_low" => "abcdef")

    expect(palette["--primary-low"]).to eq("abcdef")
  end

  it "falls back to core's base colors and returns nil for unknown variables" do
    palette = described_class.new("tertiary" => "#0a0")

    expect(palette["--tertiary"]).to eq("00aa00")
    expect(palette["--primary"]).to eq(
      described_class.normalize(ColorScheme.base_colors["primary"]),
    )
    expect(palette["--made-up"]).to be_nil
  end
end
