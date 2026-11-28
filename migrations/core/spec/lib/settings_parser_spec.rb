# frozen_string_literal: true

RSpec.describe Migrations::SettingsParser do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  def valid_options(**overrides)
    { intermediate_db: File.join(@dir, "intermediate.db"), root_paths: [@dir] }.merge(overrides)
  end

  it "reports every missing required key" do
    expect { described_class.new({}) }.to raise_error(
      described_class::ValidationError,
      "Missing required keys: intermediate_db, root_paths",
    )
  end

  describe "removed keys" do
    it "rejects each removed key and says what replaced it" do
      {
        fix_missing: "`fix_missing` has moved to the --fix-missing flag",
        create_optimized_images: "`create_optimized_images` has moved to the --optimize flag",
        thread_count_factor:
          "`thread_count_factor` is not used anymore, the number of workers now adjusts itself",
      }.each do |key, message|
        expect { described_class.new(valid_options(key => 1)) }.to raise_error(
          described_class::ValidationError,
          "#{message}; remove it from the settings file.",
        )
      end
    end

    it "rejects each removed site setting" do
      %i[
        authorized_extensions
        max_attachment_size_kb
        max_image_size_kb
        max_image_megapixels
      ].each do |key|
        options = valid_options(site_settings: { :secure_uploads => false, key => 1 })

        expect { described_class.new(options) }.to raise_error(
          described_class::ValidationError,
          /\A`site_settings.#{key}` is not used anymore, .+; remove it from the settings file\.\z/,
        )
      end
    end

    it "accepts the site settings that are still used" do
      options = valid_options(site_settings: { secure_uploads: false, enable_s3_uploads: true })

      expect { described_class.new(options) }.not_to raise_error
    end
  end

  describe "derived paths" do
    it "puts files_db and download_cache_path next to the intermediate_db by default" do
      settings = described_class.new(valid_options)

      expect(settings[:files_db]).to eq(File.join(@dir, "files.db"))
      expect(settings[:download_cache_path]).to eq(File.join(@dir, "downloads"))
    end

    it "keeps an explicit files_db and download_cache_path" do
      files_db = File.join(@dir, "elsewhere.db")
      download_cache_path = File.join(@dir, "cache")

      settings = described_class.new(valid_options(files_db:, download_cache_path:))

      expect(settings[:files_db]).to eq(files_db)
      expect(settings[:download_cache_path]).to eq(download_cache_path)
    end
  end

  describe "path validation" do
    it "raises when a db directory is not writable" do
      options = valid_options(files_db: "/does/not/exist/files.db")

      expect { described_class.new(options) }.to raise_error(
        described_class::ValidationError,
        "Directory not writable: /does/not/exist",
      )
    end

    it "raises when root_paths is not an array" do
      expect { described_class.new(valid_options(root_paths: @dir)) }.to raise_error(
        described_class::ValidationError,
        "Root paths must be an array of paths",
      )
    end

    it "raises when a root path is not readable" do
      expect { described_class.new(valid_options(root_paths: ["/does/not/exist"])) }.to raise_error(
        described_class::ValidationError,
        "Directory not readable: /does/not/exist",
      )
    end
  end
end
