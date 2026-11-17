# frozen_string_literal: true

require_relative "shared_context_for_backup_restore"

RSpec.describe BackupRestore::MetaDataHandler do
  include_context "with shared backup restore context"

  let!(:backup_filename) { "discourse-2019-11-18-143242-v20191108000414.tar.gz" }

  def with_metadata_file(content)
    Dir.mktmpdir do |directory|
      if !content.nil?
        path = File.join(directory, BackupRestore::MetaDataHandler::METADATA_FILE)
        File.write(path, content)
      end

      yield(directory)
    end
  end

  def validate_metadata(filename, tmp_directory)
    BackupRestore::MetaDataHandler.new(logger, filename, tmp_directory).validate
  end

  describe "metadata file" do
    it "extracts metadata from file when metadata file exists" do
      metadata = '{"source":"discourse","version":20160329101122}'

      with_metadata_file(metadata) do |dir|
        expect(validate_metadata(backup_filename, dir)).to include(version: 20_160_329_101_122)
      end
    end

    it "raises an exception when the metadata file contains invalid JSON" do
      corrupt_metadata = '{"version":20160329101122'

      with_metadata_file(corrupt_metadata) do |dir|
        expect { validate_metadata(backup_filename, dir) }.to raise_error(
          BackupRestore::MetaDataError,
        )
      end
    end

    it "raises an exception when the metadata file is empty" do
      with_metadata_file("") do |dir|
        expect { validate_metadata(backup_filename, dir) }.to raise_error(
          BackupRestore::MetaDataError,
        )
      end
    end

    it "raises an exception when the metadata file contains an invalid version number" do
      metadata = '{"source":"discourse","version":"1abcdefghijklm"}'

      with_metadata_file(metadata) do |dir|
        expect { validate_metadata(backup_filename, dir) }.to raise_error(
          BackupRestore::MetaDataError,
        )
      end
    end

    it "raises an exception when the metadata file contains an empty version number" do
      metadata = '{"source":"discourse","version":""}'

      with_metadata_file(metadata) do |dir|
        expect { validate_metadata(backup_filename, dir) }.to raise_error(
          BackupRestore::MetaDataError,
        )
      end
    end
  end

  describe "filename" do
    it "extracts metadata from filename when metadata file does not exist" do
      with_metadata_file(nil) do |dir|
        expect(validate_metadata(backup_filename, dir)).to include(version: 20_191_108_000_414)
      end
    end

    context "with a Discourse version in the filename" do
      around { |example| stub_const(Discourse::VERSION, "STRING", "2026.9.0") { example.run } }

      before { BackupRestore.stubs(:current_database_version).returns(20_260_923_080_644) }

      it "accepts the same release and migration version" do
        filename = "discourse-2026-09-25-120000-v2026-9-0-20260923080644.tar.gz"

        expect(validate_metadata(filename, nil)).to include(
          version: 20_260_923_080_644,
          discourse_version: "2026.9.0",
        )
      end

      it "accepts an older release" do
        filename = "discourse-2026-09-25-120000-v2026-8-0-20260923080644.sql.gz"

        expect(validate_metadata(filename, nil)[:discourse_version]).to eq("2026.8.0")
      end

      it "rejects a newer release even when the migration version is the same or older" do
        %w[20260923080644 20260901000000].each do |migration|
          filename = "discourse-2026-09-25-120000-v2026-10-0-#{migration}.tar.gz"

          expect { validate_metadata(filename, nil) }.to raise_error(
            BackupRestore::MigrationRequiredError,
            "This backup was created with Discourse 2026.10.0, " \
              "but this site is running Discourse 2026.9.0. " \
              "Upgrade this site before restoring the backup",
          )
        end
      end

      it "rejects a newer patch version" do
        filename = "discourse-2026-09-25-120000-v2026-9-1-20260923080644.tar.gz"

        expect { validate_metadata(filename, nil) }.to raise_error(
          BackupRestore::MigrationRequiredError,
          /This backup was created with Discourse/,
        )
      end

      it "rejects newer migrations within the same release" do
        filename = "discourse-2026-09-25-120000-v2026-9-0-20260923141924.tar.gz"

        expect { validate_metadata(filename, nil) }.to raise_error(
          BackupRestore::MigrationRequiredError,
          "This backup uses schema version 20260923141924, " \
            "but this site is on schema version 20260923080644. " \
            "Upgrade this site before restoring the backup",
        )
      end

      it "accepts latest backups on the matching stable release" do
        filename = "discourse-2026-09-25-120000-v2026-9-0-latest-20260923080644.tar.gz"

        expect(validate_metadata(filename, nil)[:discourse_version]).to eq("2026.9.0-latest")
      end

      it "accepts the same numbered latest version" do
        stub_const(Discourse::VERSION, "STRING", "2026.9.0-latest.1") do
          filename = "discourse-2026-09-25-120000-v2026-9-0-latest-1-20260923080644.tar.gz"

          expect(validate_metadata(filename, nil)[:discourse_version]).to eq("2026.9.0-latest.1")
        end
      end

      it "rejects a stable backup on the preceding latest version" do
        stub_const(Discourse::VERSION, "STRING", "2026.9.0-latest") do
          filename = "discourse-2026-09-25-120000-v2026-9-0-20260923080644.tar.gz"

          expect { validate_metadata(filename, nil) }.to raise_error(
            BackupRestore::MigrationRequiredError,
            /This backup was created with Discourse/,
          )
        end
      end

      it "compares numbered latest versions numerically" do
        stub_const(Discourse::VERSION, "STRING", "2026.9.0-latest.2") do
          filename = "discourse-2026-09-25-120000-v2026-9-0-latest-10-20260923080644.tar.gz"

          expect { validate_metadata(filename, nil) }.to raise_error(
            BackupRestore::MigrationRequiredError,
            /This backup was created with Discourse/,
          )
        end
      end

      it "rejects malformed combined versions" do
        %w[
          2026-9
          2026-9-x
          2026-9-0-@latest
          2026-9-0-unknown
          2026-9-0-latest-1-2
          202-9-0
          2026-999-0
        ].each do |version|
          filename = "discourse-2026-09-25-120000-v#{version}-20260923080644.tar.gz"
          expect { validate_metadata(filename, nil) }.to raise_error(BackupRestore::MetaDataError)
        end
      end
    end

    it "raises an exception when the filename contains no version number" do
      filename = "discourse-2019-11-18-143242.tar.gz"

      expect { validate_metadata(filename, nil) }.to raise_error(BackupRestore::MetaDataError)
    end

    it "raises an exception when the filename contains an invalid version number" do
      filename = "discourse-2019-11-18-143242-v123456789.tar.gz"
      expect { validate_metadata(filename, nil) }.to raise_error(BackupRestore::MetaDataError)

      filename = "discourse-2019-11-18-143242-v1abcdefghijklm.tar.gz"
      expect { validate_metadata(filename, nil) }.to raise_error(BackupRestore::MetaDataError)
    end
  end

  it "raises an exception when the backup's version is newer than the current version" do
    new_backup_filename = "discourse-2019-11-18-143242-v20191113193141.sql.gz"

    BackupRestore.expects(:current_database_version).returns(20_191_025_005_204).once

    expect { validate_metadata(new_backup_filename, nil) }.to raise_error(
      BackupRestore::MigrationRequiredError,
    )
  end
end
