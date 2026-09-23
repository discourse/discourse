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

  describe "required keys" do
    it "accepts the intermediate_db and root_paths keys" do
      expect { described_class.new(valid_options) }.not_to raise_error
    end

    it "reports every missing key by its new name" do
      expect { described_class.new({}) }.to raise_error(
        described_class::ValidationError,
        "Missing required keys: intermediate_db, root_paths",
      )
    end

    it "no longer requires files_db" do
      expect { described_class.new(valid_options) }.not_to raise_error
    end

    it "rejects the old key names" do
      options = { source_db_path: "x", output_db_path: "y", root_paths: [@dir] }

      expect { described_class.new(options) }.to raise_error(
        described_class::ValidationError,
        /Missing required keys: intermediate_db/,
      )
    end
  end

  describe "removed keys" do
    it "points fix_missing at its flag" do
      expect { described_class.new(valid_options(fix_missing: false)) }.to raise_error(
        described_class::ValidationError,
        "`fix_missing` has moved to the --fix-missing flag; remove it from the settings file.",
      )
    end

    it "points create_optimized_images at its flag" do
      expect { described_class.new(valid_options(create_optimized_images: false)) }.to raise_error(
        described_class::ValidationError,
        "`create_optimized_images` has moved to the --optimize flag; remove it from the settings file.",
      )
    end
  end

  describe "derived paths" do
    it "defaults files_db to files.db next to the intermediate_db" do
      settings = described_class.new(valid_options)

      expect(settings[:files_db]).to eq(File.join(@dir, "files.db"))
    end

    it "defaults download_cache_path to a downloads directory next to the intermediate_db" do
      settings = described_class.new(valid_options)

      expect(settings[:download_cache_path]).to eq(File.join(@dir, "downloads"))
    end

    it "keeps an explicit files_db" do
      explicit = File.join(@dir, "elsewhere.db")
      settings = described_class.new(valid_options(files_db: explicit))

      expect(settings[:files_db]).to eq(explicit)
    end

    it "keeps an explicit download_cache_path" do
      explicit = File.join(@dir, "cache")
      settings = described_class.new(valid_options(download_cache_path: explicit))

      expect(settings[:download_cache_path]).to eq(explicit)
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

  describe "accessors" do
    subject(:settings) { described_class.new(valid_options) }

    it "reads and writes options" do
      settings[:fix_missing] = true

      expect(settings[:fix_missing]).to be(true)
      expect(settings.fetch(:missing, :default)).to eq(:default)
    end
  end
end
