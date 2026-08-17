# frozen_string_literal: true

require "letter_avatar"

RSpec.describe LetterAvatar do
  describe ".vips_version" do
    before do
      described_class.instance_variable_set(:@vips_version, nil)
      Discourse::Utils.stubs(execute_command: "font\n")
    end

    it "includes installation guidance outside production" do
      Rails.stubs(env: ActiveSupport::EnvironmentInquirer.new("development"))
      Vips
        .expects(:run)
        .with("vips", "--version", failure_message: <<~TEXT.strip)
            Discourse requires the `vips` command for image processing, but it could not be run.

            Install libvips, then restart Discourse:
            https://www.libvips.org/install.html
          TEXT
        .returns("vips-8.18.4\n")

      expect(described_class.vips_version).to be_present
    end

    it "preserves the normal command error in production" do
      Rails.stubs(env: ActiveSupport::EnvironmentInquirer.new("production"))
      Vips.expects(:run).with("vips", "--version", failure_message: "").returns("vips-8.18.4\n")

      expect(described_class.vips_version).to be_present
    end
  end

  describe ".cleanup_old" do
    it "removes stale cache directories" do
      cache_path = LetterAvatar.cache_path
      parent_path = File.dirname(cache_path)
      stale_path = File.join(parent_path, "stale")
      FileUtils.mkdir_p([cache_path, stale_path])

      described_class.cleanup_old

      expect(Dir.children(parent_path)).to contain_exactly(File.basename(cache_path))
    end
  end

  describe ".generate" do
    it "generates a PNG avatar with the requested dimensions" do
      username = "A"
      avatar_size = 45
      generated_path = described_class.generate(username, avatar_size, cache: false)

      expect(FastImage.type(generated_path)).to eq(:png)
      expect(FastImage.size(generated_path)).to eq([avatar_size, avatar_size])
    ensure
      if generated_path
        identity = LetterAvatar::Identity.from_username(username)
        FileUtils.rm_f(generated_path)
        FileUtils.rm_f(described_class.fullsize_path(identity))
      end
    end
  end
end
