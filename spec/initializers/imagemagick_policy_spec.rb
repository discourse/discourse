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

  it "processes temporary images when the configured temporary directory is a symlink" do
    original_tmpdir = ENV["TMPDIR"]
    avatar_size = Discourse.avatar_sizes.first

    Dir.mktmpdir(nil, File.realpath(Dir.tmpdir)) do |directory|
      linked_directory = File.join(directory, "linked")
      File.symlink(directory, linked_directory)
      ENV["TMPDIR"] = linked_directory

      load Rails.root.join("config/initializers/003-imagemagick.rb")

      Dir.mktmpdir do |image_directory|
        input = File.join(image_directory, "input.png")
        output = File.join(image_directory, "output.png")
        FileUtils.cp(Rails.root.join("spec/fixtures/images/logo.png"), input)

        ImageMagick.magick(
          input,
          "-resize",
          "#{avatar_size}x#{avatar_size}!",
          output,
          operation: :avatar_resize,
          read: [input],
          write: [image_directory],
        )

        expect(FastImage.size(output)).to eq([avatar_size, avatar_size])
      end
    end
  ensure
    ENV["TMPDIR"] = original_tmpdir
  end
end
