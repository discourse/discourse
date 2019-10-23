# frozen_string_literal: true

require 'rails_helper'

describe BackupRestore::Restorer do
  it 'detects which pg_dump output is restorable to different schemas' do
    {
      "9.6.7" => true,
      "9.6.8" => false,
      "9.6.9" => false,
      "10.2" => true,
      "10.3" => false,
      "10.3.1" => false,
      "10.4" => false,
      "11" => false,
      "11.4" => false,
      "21" => false,
    }.each do |key, value|
      expect(described_class.pg_produces_portable_dump?(key)).to eq(value)
    end
  end

  describe 'Decompressing a backup' do
    fab!(:admin) { Fabricate(:admin) }

    before do
      SiteSetting.allow_restore = true
      @restore_path = File.join(Rails.root, "public", "backups", RailsMultisite::ConnectionManagement.current_db)
    end

    after do
      FileUtils.rm_rf @restore_path
      FileUtils.rm_rf @restorer.tmp_directory
    end

    context 'When there are uploads' do
      before do
        @restore_folder = "backup-#{SecureRandom.hex}"
        @temp_folder = "#{@restore_path}/#{@restore_folder}"
        FileUtils.mkdir_p("#{@temp_folder}/uploads")

        Dir.chdir(@restore_path) do
          File.write("#{@restore_folder}/dump.sql", 'This is a dump')
          Compression::Gzip.new.compress(@restore_folder, 'dump.sql')
          FileUtils.rm_rf("#{@restore_folder}/dump.sql")
          File.write("#{@restore_folder}/uploads/upload.txt", 'This is an upload')

          Compression::Tar.new.compress(@restore_path, @restore_folder)
        end

        Compression::Gzip.new.compress(@restore_path, "#{@restore_folder}.tar")
        FileUtils.rm_rf @temp_folder

        build_restorer("#{@restore_folder}.tar.gz")
      end

      it '#decompress_archive works correctly' do
        @restorer.decompress_archive

        expect(exists?("dump.sql.gz")).to eq(true)
        expect(exists?("uploads", directory: true)).to eq(true)
      end

      it '#extract_dump works correctly' do
        @restorer.decompress_archive
        @restorer.extract_dump

        expect(exists?('dump.sql')).to eq(true)
      end
    end

    context 'When restoring a single file' do
      before do
        FileUtils.mkdir_p(@restore_path)

        Dir.chdir(@restore_path) do
          File.write('dump.sql', 'This is a dump')
          Compression::Gzip.new.compress(@restore_path, 'dump.sql')
          FileUtils.rm_rf('dump.sql')
        end

        build_restorer('dump.sql.gz')
      end

      it '#extract_dump works correctly with a single file' do
        @restorer.extract_dump

        expect(exists?("dump.sql")).to eq(true)
      end
    end

    def exists?(relative_path, directory: false)
      full_path = "#{@restorer.tmp_directory}/#{relative_path}"
      directory ? File.directory?(full_path) : File.exists?(full_path)
    end

    def build_restorer(filename)
      @restorer = described_class.new(admin.id, filename: filename)
      @restorer.ensure_directory_exists(@restorer.tmp_directory)
      @restorer.copy_archive_to_tmp_directory
    end
  end

  context 'Database connection' do
    fab!(:admin) { Fabricate(:admin) }
    before do
      SiteSetting.allow_restore = true
      @restore_path = File.join(Rails.root, 'public', 'backups', RailsMultisite::ConnectionManagement.current_db)
      described_class.any_instance.stubs(ensure_we_have_a_filename: true)
      described_class.any_instance.stubs(initialize_state: true)
    end
    let(:conn) { RailsMultisite::ConnectionManagement }
    let(:restorer) { described_class.new(admin.id) }

    it 'correctly reconnects to database' do
      restorer.instance_variable_set(:@current_db, 'second')
      conn.config_filename = "spec/fixtures/multisite/two_dbs.yml"
      conn.establish_connection(db: 'second')
      expect(RailsMultisite::ConnectionManagement.current_db).to eq('second')
      ActiveRecord::Base.connection_pool.spec.config[:db_key] = "incorrect_db"
      restorer.send(:reconnect_database)
      expect(RailsMultisite::ConnectionManagement.current_db).to eq('second')
    end
  end
end
