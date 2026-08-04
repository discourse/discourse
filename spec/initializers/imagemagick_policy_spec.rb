# frozen_string_literal: true

require "chunky_png"

# Guards config/imagemagick/policy.xml. A malformed policy fails open silently
# (e.g. a stray backtick drops every rule after it), so assert it is parsed and
# enforced.
RSpec.describe "ImageMagick security policy" do
  it "loads the coder allowlist" do
    policy = Discourse::Utils.execute_command("magick", "-list", "policy")

    expect(policy).to match(/Policy: Coder/i)
    expect(policy).to include("MSVG")
  end

  it "blocks a coder that is not on the allowlist" do
    png = Rails.root.join("spec/fixtures/images/logo.png").to_s

    expect { Discourse::Utils.execute_command("identify", "TIFF:#{png}") }.to raise_error(
      Discourse::Utils::CommandError,
      /not (allowed|authorized) by the security policy/,
    )
  end

  it "loads SVG images only through the MSVG coder" do
    Dir.mktmpdir("imagemagick-policy", Rails.root.join("tmp")) do |directory|
      svg_path = File.join(directory, "source.svg")
      msvg_png_path = File.join(directory, "msvg.png")
      svg_png_path = File.join(directory, "svg.png")
      environment = { "MAGICK_TEMPORARY_PATH" => directory, "TMPDIR" => directory }
      File.write(
        svg_path,
        '<svg xmlns="http://www.w3.org/2000/svg" width="2" height="3"><rect width="2" height="3" fill="#ff0000"/></svg>',
      )

      Discourse::Utils.execute_command(environment, "magick", "MSVG:#{svg_path}", msvg_png_path)

      expect(FastImage.type(msvg_png_path)).to eq(:png)
      expect(FastImage.size(msvg_png_path)).to eq([2, 3])
      expect do
        Discourse::Utils.execute_command(environment, "magick", svg_path, svg_png_path)
      end.to raise_error(
        Discourse::Utils::CommandError,
        /not (allowed|authorized) by the security policy/,
      )
      expect(File.exist?(svg_png_path)).to eq(false)
    end
  end

  it "ignores Gaussian blur filters through the MSVG coder" do
    unfiltered_svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
        <rect x="5" y="5" width="10" height="10" fill="#00ff00"/>
      </svg>
    SVG
    filtered_svg = <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20">
        <defs>
          <filter id="blur">
            <feGaussianBlur stdDeviation="4"/>
          </filter>
        </defs>
        <rect x="5" y="5" width="10" height="10" fill="#00ff00" filter="url(#blur)"/>
      </svg>
    SVG

    Dir.mktmpdir("imagemagick-policy", Rails.root.join("tmp")) do |directory|
      unfiltered_path = File.join(directory, "unfiltered.svg")
      filtered_path = File.join(directory, "filtered.svg")
      unfiltered_png_path = File.join(directory, "unfiltered.png")
      filtered_png_path = File.join(directory, "filtered.png")
      environment = { "MAGICK_TEMPORARY_PATH" => directory, "TMPDIR" => directory }
      File.write(unfiltered_path, unfiltered_svg)
      File.write(filtered_path, filtered_svg)

      Discourse::Utils.execute_command(
        environment,
        "magick",
        "MSVG:#{unfiltered_path}",
        unfiltered_png_path,
      )
      Discourse::Utils.execute_command(
        environment,
        "magick",
        "MSVG:#{filtered_path}",
        filtered_png_path,
      )

      expect(ChunkyPNG::Image.from_file(filtered_png_path)).to eq(
        ChunkyPNG::Image.from_file(unfiltered_png_path),
      )
    end
  end
end
