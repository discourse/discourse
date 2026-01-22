# frozen_string_literal: true

RSpec.describe BackupRestore::Backuper do
  describe "#add_remote_uploads_to_archive" do
    fab!(:user)

    let(:backuper) { described_class.new(user.id) }
    let(:tar_filename) { "/tmp/test_backup.tar" }

    before do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_access_key_id = "abc"
      SiteSetting.s3_secret_access_key = "def"
      SiteSetting.s3_upload_bucket = "bucket"
      SiteSetting.include_s3_uploads_in_backups = true

      # Initialize the backuper's tmp directory
      backuper.instance_variable_set(:@tmp_directory, Dir.mktmpdir)
      backuper.instance_variable_set(:@logs, [])
    end

    after { FileUtils.rm_rf(backuper.instance_variable_get(:@tmp_directory)) }

    it "deduplicates uploads with the same original_sha1 using hardlinks" do
      shared_sha1 = SecureRandom.hex(20)

      # Create 3 uploads with the same original_sha1 (simulating secure upload duplicates)
      upload1 =
        Fabricate(
          :upload,
          sha1: SecureRandom.hex(20),
          original_sha1: shared_sha1,
          url: "//bucket.s3.amazonaws.com/original/1X/file1.png",
        )
      upload2 =
        Fabricate(
          :upload,
          sha1: SecureRandom.hex(20),
          original_sha1: shared_sha1,
          url: "//bucket.s3.amazonaws.com/original/2X/file2.png",
        )
      upload3 =
        Fabricate(
          :upload,
          sha1: SecureRandom.hex(20),
          original_sha1: shared_sha1,
          url: "//bucket.s3.amazonaws.com/original/3X/file3.png",
        )

      # Create 1 unique upload
      unique_upload =
        Fabricate(
          :upload,
          sha1: SecureRandom.hex(20),
          original_sha1: SecureRandom.hex(20),
          url: "//bucket.s3.amazonaws.com/original/4X/file4.png",
        )

      store = FileStore::S3Store.new
      download_count = 0

      # Stub get_path_for_upload to extract path from URL (works with UploadData structs)
      store
        .stubs(:get_path_for_upload)
        .with { |obj| obj.url.include?("1X") }
        .returns("original/1X/file1.png")
      store
        .stubs(:get_path_for_upload)
        .with { |obj| obj.url.include?("2X") }
        .returns("original/2X/file2.png")
      store
        .stubs(:get_path_for_upload)
        .with { |obj| obj.url.include?("3X") }
        .returns("original/3X/file3.png")
      store
        .stubs(:get_path_for_upload)
        .with { |obj| obj.url.include?("4X") }
        .returns("original/4X/file4.png")

      store
        .stubs(:download_file)
        .with do |upload_data, filename|
          download_count += 1
          FileUtils.mkdir_p(File.dirname(filename))
          File.write(filename, "file content for #{upload_data.id}")
          true
        end
        .returns(nil)

      FileStore::S3Store.stubs(:new).returns(store)

      Discourse::Utils.stubs(:execute_command)

      silence_stdout { backuper.send(:add_remote_uploads_to_archive, tar_filename) }

      # Should only download 2 files: 1 for the duplicates group + 1 for the unique upload
      expect(download_count).to eq(2)

      # All 4 file paths should exist in the tmp directory
      tmp_dir = backuper.instance_variable_get(:@tmp_directory)
      upload_dir = Discourse.store.upload_path
      expect(File.exist?(File.join(tmp_dir, upload_dir, "original/1X/file1.png"))).to eq(true)
      expect(File.exist?(File.join(tmp_dir, upload_dir, "original/2X/file2.png"))).to eq(true)
      expect(File.exist?(File.join(tmp_dir, upload_dir, "original/3X/file3.png"))).to eq(true)
      expect(File.exist?(File.join(tmp_dir, upload_dir, "original/4X/file4.png"))).to eq(true)

      # The duplicate files should be hardlinks (same inode as the primary)
      file1_stat = File.stat(File.join(tmp_dir, upload_dir, "original/1X/file1.png"))
      file2_stat = File.stat(File.join(tmp_dir, upload_dir, "original/2X/file2.png"))
      file3_stat = File.stat(File.join(tmp_dir, upload_dir, "original/3X/file3.png"))

      expect(file1_stat.ino).to eq(file2_stat.ino)
      expect(file1_stat.ino).to eq(file3_stat.ino)
    end
  end

  describe "#get_parameterized_title" do
    it "returns a non-empty parameterized title when site title contains unicode" do
      SiteSetting.title = "Ɣ"
      backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

      expect(backuper.send(:get_parameterized_title)).to eq("discourse")
    end

    it "truncates the title to 64 chars" do
      SiteSetting.title = "This is th title of a very long site that is going to be truncated"
      backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

      expect(backuper.send(:get_parameterized_title).length).to eq(64)
    end

    it "returns a valid parameterized site title" do
      SiteSetting.title = "Coding Horror"
      backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

      expect(backuper.send(:get_parameterized_title)).to eq("coding-horror")
    end
  end

  describe "#notify_user" do
    before { freeze_time Time.zone.parse("2010-01-01 12:00") }

    it "includes logs if short" do
      SiteSetting.max_export_file_size_kb = 1
      SiteSetting.export_authorized_extensions = "tar.gz"

      silence_stdout do
        backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

        expect { backuper.send(:notify_user) }.to change { Topic.private_messages.count }.by(
          1,
        ).and not_change { Upload.count }
      end

      expect(Topic.last.first_post.raw).to include(
        "```text\n[2010-01-01 12:00:00] Notifying 'system' of the end of the backup...\n```",
      )
    end

    it "include upload if log is long" do
      SiteSetting.max_post_length = 250

      silence_stdout do
        backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

        expect { backuper.send(:notify_user) }.to change { Topic.private_messages.count }.by(
          1,
        ).and change { Upload.where(original_filename: "log.txt.zip").count }.by(1)
      end

      expect(Topic.last.first_post.raw).to include("[log.txt.zip|attachment]")
    end

    it "includes trimmed logs if log is long and upload cannot be saved" do
      SiteSetting.max_post_length = 348
      SiteSetting.max_export_file_size_kb = 1
      SiteSetting.export_authorized_extensions = "tar.gz"

      silence_stdout do
        backuper = BackupRestore::Backuper.new(Discourse.system_user.id)

        1.upto(10).each { |i| backuper.send(:log, "Line #{i}") }

        expect { backuper.send(:notify_user) }.to change { Topic.private_messages.count }.by(
          1,
        ).and not_change { Upload.count }
      end

      expect(Topic.last.first_post.raw).to include(
        "```text\n...\n[2010-01-01 12:00:00] Line 10\n[2010-01-01 12:00:00] Notifying 'system' of the end of the backup...\n```",
      )
    end
  end

  describe "#run" do
    subject(:run) { backup.run }

    let(:backup) { described_class.new(user.id) }
    let(:user) { Discourse.system_user }
    let(:store) { backup.store }

    before { backup.stubs(:success).returns(success) }

    context "when the result is successful" do
      let(:success) { true }
      it "refreshes disk stats" do
        store.expects(:reset_cache).at_least_once
        run
      end
    end
  end
end
