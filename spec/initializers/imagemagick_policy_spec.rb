# frozen_string_literal: true

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

  it "allows SVG rasterization only through the MSVG coder" do
    Dir.mktmpdir do |dir|
      svg = File.join(dir, "source.svg")
      png = File.join(dir, "output.png")
      denied_png = File.join(dir, "denied.png")

      File.write(
        svg,
        '<svg xmlns="http://www.w3.org/2000/svg" width="2" height="3"><rect width="2" height="3" fill="#ff0000"/></svg>',
      )

      Discourse::Utils.execute_command("magick", "MSVG:#{svg}", png)

      expect(FastImage.type(png)).to eq(:png)
      expect(FastImage.size(png)).to eq([2, 3])
      expect { Discourse::Utils.execute_command("magick", svg, denied_png) }.to raise_error(
        Discourse::Utils::CommandError,
        /not (allowed|authorized) by the security policy/,
      )
      expect(File.exist?(denied_png)).to eq(false)
    end
  end
end
