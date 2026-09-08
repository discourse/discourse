# frozen_string_literal: true

RSpec.describe Migrations::Importer::CLI::UploadCommand do
  let(:files_db_path) { "/tmp/does-not-matter/files.db" }
  let(:parsed_settings) { { files_db: files_db_path } }

  before do
    allow(Migrations::Importer::Uploads::Uploads).to receive(:perform!)
    allow(Migrations::Database).to receive(:delete_database)
    allow(Migrations::SettingsParser).to receive(:parse!).and_return(parsed_settings)
    allow(File).to receive(:exist?).and_return(true)
  end

  describe "#call" do
    it "parses the settings and runs the uploads without touching files.db" do
      described_class.new([]).call

      expect(Migrations::Database).not_to have_received(:delete_database)
      expect(Migrations::Importer::Uploads::Uploads).to have_received(:perform!).with(
        parsed_settings,
      )
    end

    it "deletes files.db before running when --reset is given" do
      described_class.new(["--reset"]).call

      expect(Migrations::Database).to have_received(:delete_database).with(files_db_path)
      expect(Migrations::Importer::Uploads::Uploads).to have_received(:perform!)
    end

    it "leaves the modes off when no flag is passed" do
      described_class.new([]).call

      expect(Migrations::Importer::Uploads::Uploads).to have_received(:perform!).with(
        hash_excluding(:fix_missing, :create_optimized_images),
      )
    end

    it "OR-s the --fix-missing flag into the settings" do
      described_class.new(["--fix-missing"]).call

      expect(Migrations::Importer::Uploads::Uploads).to have_received(:perform!).with(
        hash_including(fix_missing: true),
      )
    end

    it "OR-s the --optimize flag into the settings" do
      described_class.new(["--optimize"]).call

      expect(Migrations::Importer::Uploads::Uploads).to have_received(:perform!).with(
        hash_including(create_optimized_images: true),
      )
    end

    it "raises when the settings file is missing" do
      allow(File).to receive(:exist?).and_return(false)

      expect { described_class.new([]).call }.to raise_error(Migrations::NoSettingsFound)
    end

    it "prefers upload.local.yml when no --settings is given" do
      allow(File).to receive(:exist?).with(described_class::LOCAL_SETTINGS_PATH).and_return(true)

      described_class.new([]).call

      expect(Migrations::SettingsParser).to have_received(:parse!).with(
        described_class::LOCAL_SETTINGS_PATH,
      )
    end

    it "falls back to the upload.yml template when no local override exists" do
      allow(File).to receive(:exist?).with(described_class::LOCAL_SETTINGS_PATH).and_return(false)

      described_class.new([]).call

      expect(Migrations::SettingsParser).to have_received(:parse!).with(
        described_class::SETTINGS_TEMPLATE_PATH,
      )
    end

    it "uses an explicit --settings path over the defaults" do
      described_class.new(%w[--settings /path/to/custom.yml]).call

      expect(Migrations::SettingsParser).to have_received(:parse!).with("/path/to/custom.yml")
    end
  end
end
