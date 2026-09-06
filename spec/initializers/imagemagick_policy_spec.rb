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
end
