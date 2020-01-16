# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_context_for_backup_restore'

describe BackupRestore::MetaDataHandler do
  include_context "shared stuff"

  let!(:backup_filename) { 'discourse-2019-11-18-143242-v20191108000414.tar.gz' }

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

  context "metadata file" do
    it "extracts metadata from file when metadata file exists" do
      metadata = '{"source":"discourse","version":20160329101122}'

      with_metadata_file(metadata) do |dir|
        expect(validate_metadata(backup_filename, dir))
          .to include(version: 20160329101122)
      end
    end

    it "raises an exception when the metadata file contains invalid JSON" do
      currupt_metadata = '{"version":20160329101122'

      with_metadata_file(currupt_metadata) do |dir|
        expect { validate_metadata(backup_filename, dir) }
          .to raise_error(BackupRestore::MetaDataError)
      end
    end

    it "raises an exception when the metadata file is empty" do
      with_metadata_file('') do |dir|
        expect { validate_metadata(backup_filename, dir) }
          .to raise_error(BackupRestore::MetaDataError)
      end
    end

    it "raises an exception when the metadata file contains an invalid version number" do
      metadata = '{"source":"discourse","version":"1abcdefghijklm"}'

      with_metadata_file(metadata) do |dir|
        expect { validate_metadata(backup_filename, dir) }
          .to raise_error(BackupRestore::MetaDataError)
      end
    end

    it "raises an exception when the metadata file contains an empty version number" do
      metadata = '{"source":"discourse","version":""}'

      with_metadata_file(metadata) do |dir|
        expect { validate_metadata(backup_filename, dir) }
          .to raise_error(BackupRestore::MetaDataError)
      end
    end
  end

  context "filename" do
    it "extracts metadata from filename when metadata file does not exist" do
      with_metadata_file(nil) do |dir|
        expect(validate_metadata(backup_filename, dir))
          .to include(version: 20191108000414)
      end
    end

    it "raises an exception when the filename contains no version number" do
      filename = 'discourse-2019-11-18-143242.tar.gz'

      expect { validate_metadata(filename, nil) }
        .to raise_error(BackupRestore::MetaDataError)
    end

    it "raises an exception when the filename contains an invalid version number" do
      filename = 'discourse-2019-11-18-143242-v123456789.tar.gz'
      expect { validate_metadata(filename, nil) }
        .to raise_error(BackupRestore::MetaDataError)

      filename = 'discourse-2019-11-18-143242-v1abcdefghijklm.tar.gz'
      expect { validate_metadata(filename, nil) }
        .to raise_error(BackupRestore::MetaDataError)
    end
  end

  it "raises an exception when the backup's version is newer than the current version" do
    new_backup_filename = 'discourse-2019-11-18-143242-v20191113193141.sql.gz'

    BackupRestore.expects(:current_version)
      .returns(20191025005204).once

    expect { validate_metadata(new_backup_filename, nil) }
      .to raise_error(BackupRestore::MigrationRequiredError)
  end
end
