# frozen_string_literal: true

describe BackupRestore::Creator do
  describe "backup filenames" do
    it "includes the Discourse version and migration version for both backup types" do
      freeze_time(Time.utc(2026, 9, 25, 12))
      SiteSetting.title = "My forum"
      BackupRestore.stubs(:current_database_version).returns(20_260_923_080_644)
      stub_const(Discourse::VERSION, "STRING", "2026.9.0-latest") do
        described_class.any_instance.stubs(:include_uploads?).returns(true)

        [true, false].each do |with_uploads|
          creator = described_class.new(nil, with_uploads: with_uploads)

          expect(creator.instance_variable_get(:@backup_filename)).to eq(
            "my-forum-2026-09-25-120000-v2026-9-0-latest-20260923080644.tar",
          )
        end
      end
    end
  end

  describe "#pg_dump_command" do
    it "passes credentials literally through the environment and arguments" do
      config = BackupRestore.database_configuration.dup
      config.password = "password ' $HOME ;"
      config.username = "user with spaces"
      config.database = "database ' $HOME ;"
      BackupRestore.stubs(:database_configuration).returns(config)

      command = described_class.new(nil).send(:pg_dump_command)

      expect(command.first).to eq("PGPASSWORD" => config.password)
      expect(command).to include("--username=#{config.username}", config.database)
    end

    [0, 1, 4].each do |concurrency|
      it "uses directory format with at least one worker when configured with #{concurrency}" do
        GlobalSetting.stubs(:backup_database_concurrency).returns(concurrency)
        command = described_class.new(nil).send(:pg_dump_command)

        expect(command).to include("--format=directory", "--jobs=#{[concurrency, 1].max}")
      end
    end

    it "excludes disposable nested hot score data" do
      command = described_class.new(Discourse.system_user.id).send(:pg_dump_command)

      expect(command).to include(
        "--exclude-table-data=public.nested_hot_post_scores",
        "--exclude-table-data=public.nested_hot_score_snapshots",
      )
    end
  end

  describe "#add_remote_uploads_to_archive" do
    fab!(:user)

    let(:creator) { described_class.new(user.id) }

    before do
      SiteSetting.enable_s3_uploads = true
      SiteSetting.s3_access_key_id = "abc"
      SiteSetting.s3_secret_access_key = "def"
      SiteSetting.s3_upload_bucket = "bucket"
      SiteSetting.include_s3_uploads_in_backups = true

      # Initialize the creator's tmp directory
      creator.instance_variable_set(:@tmp_directory, Dir.mktmpdir)
      creator.instance_variable_set(:@logs, [])
    end

    after { FileUtils.rm_rf(creator.instance_variable_get(:@tmp_directory)) }

    def archive_remote_uploads
      directory = creator.instance_variable_get(:@tmp_directory)
      filename = File.join(directory, "backup.tar")
      creator.instance_variable_set(:@archive_mutex, Mutex.new)
      BackupRestore::ArchiveWriter.open(filename) do |archive|
        creator.instance_variable_set(:@archive, archive)
        silence_stdout { creator.send(:add_remote_uploads_to_archive) }
      end
      expect(Dir.glob(File.join(directory, "backup-upload-*"))).to be_empty
      extracted = File.join(directory, "extracted")
      FileUtils.mkdir_p(extracted)
      Discourse::Utils.execute_command("tar", "-xf", filename, "-C", extracted)
      extracted
    end

    [1, 4].each do |concurrency|
      context "with #{concurrency} download workers" do
        before do
          GlobalSetting.stubs(:backup_s3_download_concurrency).returns(concurrency)
          S3Helper.any_instance.stubs(:object).returns(nil)
        end

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

          tmp_dir = archive_remote_uploads

          # Should only download 2 files: 1 for the duplicates group + 1 for the unique upload
          expect(download_count).to eq(2)

          # All 4 file paths should exist in the tmp directory
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

        it "skips duplicate uploads with the same path" do
          shared_sha1 = SecureRandom.hex(20)
          shared_url = "//bucket.s3.amazonaws.com/original/2X/3/#{shared_sha1}.png"

          Fabricate(
            :upload,
            sha1: SecureRandom.hex(20),
            original_sha1: shared_sha1,
            url: shared_url,
          )
          Fabricate(:upload, sha1: shared_sha1, original_sha1: nil, url: shared_url)

          store = FileStore::S3Store.new
          download_count = 0

          store.stubs(:get_path_for_upload).returns("original/2X/3/#{shared_sha1}.png")
          store
            .stubs(:download_file)
            .with do |_upload_data, filename|
              download_count += 1
              FileUtils.mkdir_p(File.dirname(filename))
              File.write(filename, "file content")
              true
            end
            .returns(nil)

          FileStore::S3Store.stubs(:new).returns(store)
          tmp_dir = archive_remote_uploads

          upload_path =
            File.join(tmp_dir, Discourse.store.upload_path, "original/2X/3/#{shared_sha1}.png")

          expect(download_count).to eq(1)
          expect(File.read(upload_path)).to eq("file content")
        end

        it "bounds temporary downloads to the worker count and removes them after archiving" do
          uploads =
            12.times.map do |id|
              described_class::UploadData.new(
                id: id,
                url: "//bucket.s3.amazonaws.com/#{id}",
                sha1: id.to_s,
                extension: "txt",
                original_filename: "#{id}.txt",
              )
            end
          creator.stubs(:group_remote_uploads_by_sha1).returns(uploads.index_with { |u| [u] })
          store = FileStore::S3Store.new
          FileStore::S3Store.stubs(:new).returns(store)
          store.define_singleton_method(:get_path_for_upload) do |upload|
            "original/#{upload.id}.txt"
          end
          staged_counts = Queue.new
          store
            .stubs(:download_file)
            .with do |_upload, filename|
              File.write(filename, "download")
              staged_counts << Dir.glob(File.join(File.dirname(filename), "backup-upload-*")).size
              true
            end

          extracted = archive_remote_uploads

          expect(12.times.map { staged_counts.pop }.max).to be <= concurrency
          uploads.each do |upload|
            path = File.join(extracted, Discourse.store.upload_path, "original/#{upload.id}.txt")
            expect(File.read(path)).to eq("download")
            expect(File.stat(path).mode & 0o777).to eq(0o644)
          end
        end

        it "discards failed downloads without adding partial files to the archive" do
          upload = Fabricate(:upload)
          store = FileStore::S3Store.new
          FileStore::S3Store.stubs(:new).returns(store)
          store.define_singleton_method(:download_file) do |_upload, filename|
            File.write(filename, "partial download")
            raise "Download failed"
          end

          extracted = archive_remote_uploads

          expect(Dir.empty?(extracted)).to eq(true)
          expect(creator.instance_variable_get(:@logs).join).to include("#{upload.id}")
        end
      end
    end
  end

  describe "#create_archive" do
    it "streams remote backups without creating a local archive" do
      Dir.mktmpdir do |directory|
        dump = File.join(directory, "db")
        FileUtils.mkdir_p(dump)
        File.write(File.join(dump, "toc.dat"), "database")
        creator = described_class.new(nil, with_uploads: false)
        creator.instance_variable_set(:@dump_filename, dump)
        creator.instance_variable_set(:@archive_basename, File.join(directory, "backup"))
        creator.instance_variable_set(:@tmp_directory, File.join(directory, "tmp"))
        store = stub(remote?: true)
        creator.instance_variable_set(:@store, store)
        io = StringIO.new
        store
          .expects(:upload_stream)
          .with(creator.instance_variable_get(:@backup_filename), "application/x-tar")
          .yields(io)
        store.expects(:upload_file).never

        creator.send(:create_archive)

        expect(Dir.glob(File.join(directory, "backup*"))).to be_empty
        io.rewind
        entries = {}
        Gem::Package::TarReader.new(io) do |tar|
          tar.each { |entry| entries[entry.full_name] = entry.read if entry.file? }
        end
        expect(entries).to eq("db/toc.dat" => "database")
        expect(io.string.end_with?("\0" * 1024)).to eq(true)
      end
    end

    it "keeps completed tar backups during cleanup" do
      Dir.mktmpdir do |directory|
        completed = File.join(directory, "backup.tar")
        partial = File.join(directory, "backup.tar.partial")
        File.write(completed, "completed")
        File.write(partial, "partial")
        creator = described_class.new(nil)
        creator.instance_variable_set(:@archive_directory, directory)

        creator.send(:remove_partial_archives)

        expect(File.read(completed)).to eq("completed")
        expect(File.exist?(partial)).to eq(false)
      end
    end

    [RuntimeError, SystemExit].each do |error|
      it "removes the partial archive when interrupted by #{error}" do
        Dir.mktmpdir do |directory|
          dump = File.join(directory, "db")
          FileUtils.mkdir_p(dump)
          File.write(File.join(dump, "toc.dat"), "database")
          creator = described_class.new(nil, with_uploads: false)
          creator.instance_variable_set(:@dump_filename, dump)
          creator.instance_variable_set(:@archive_basename, File.join(directory, "backup"))
          BackupRestore::ArchiveWriter.any_instance.expects(:add_file).raises(error)

          expect { creator.send(:create_archive) }.to raise_error(error)

          expect(Dir.glob(File.join(directory, "backup*"))).to be_empty
        end
      end
    end
  end

  describe "#download_upload_groups" do
    let(:creator) { described_class.new(nil) }

    before do
      store = stub(s3_helper: stub(object: nil))
      creator.instance_variable_set(:@s3_store, store)
    end

    it "processes groups on the calling thread when concurrency is 1" do
      GlobalSetting.stubs(:backup_s3_download_concurrency).returns(1)
      threads = []
      creator.define_singleton_method(:process_upload_group) { |_| threads << Thread.current }

      creator.send(:download_upload_groups, [1, 2])

      expect(threads).to eq([Thread.current, Thread.current])
    end

    it "finishes active downloads and skips queued groups when the backup is cancelled" do
      GlobalSetting.stubs(:backup_s3_download_concurrency).returns(2)
      arrivals = Queue.new
      release = Queue.new
      cleanup_started = Queue.new
      finished = Queue.new
      active_workers = []
      backup_thread = nil
      instance = creator
      instance.define_singleton_method(:process_upload_group) do |group|
        arrivals << [group, Thread.current]
        release.pop
        finished << group
      end

      begin
        Timeout.timeout(10) do
          backup_thread =
            Thread.new do
              Thread.current.report_on_exception = false
              instance.send(:download_upload_groups, [1, 2, 3])
            end
          active_workers = 2.times.map { arrivals.pop.last }
          # Observe the cancellation join, after the ensure block clears the queue.
          active_workers.each do |worker|
            worker.define_singleton_method(:join) do |*args|
              cleanup_started << true if $!.is_a?(SystemExit)
              super(*args)
            end
          end

          backup_thread.raise(SystemExit)
          cleanup_started.pop
          expect(finished.size).to eq(0)
          2.times { release << true }
          expect { backup_thread.value }.to raise_error(SystemExit)

          expect(2.times.map { finished.pop }.sort).to eq([1, 2])
          expect(arrivals).to be_empty
          expect(active_workers.none?(&:alive?)).to eq(true)
        end
      ensure
        # Unblock workers even if an assertion or the timeout fails.
        3.times { release << true }
        if backup_thread
          backup_thread.kill if backup_thread.alive?
          begin
            backup_thread.join
          rescue SystemExit
          end
        end
      end
    end

    it "propagates ordinary worker failures after all workers finish" do
      GlobalSetting.stubs(:backup_s3_download_concurrency).returns(2)
      barrier = Concurrent::CyclicBarrier.new(2)
      workers = Queue.new
      creator.define_singleton_method(:process_upload_group) do |group|
        workers << Thread.current
        raise "Workers did not start" unless barrier.wait(5)
        raise "Download group failed" if group == 1
      end

      expect do
        Timeout.timeout(10) { creator.send(:download_upload_groups, [1, 2]) }
      end.to raise_error(RuntimeError, "Download group failed")
      expect(2.times.map { workers.pop }.none?(&:alive?)).to eq(true)
    end
  end

  describe "#get_parameterized_title" do
    it "returns a non-empty parameterized title when site title contains unicode" do
      SiteSetting.title = "Ɣ"
      creator = BackupRestore::Creator.new(Discourse.system_user.id)

      expect(creator.send(:get_parameterized_title)).to eq("discourse")
    end

    it "truncates the title to 64 chars" do
      SiteSetting.title = "This is th title of a very long site that is going to be truncated"
      creator = BackupRestore::Creator.new(Discourse.system_user.id)

      expect(creator.send(:get_parameterized_title).length).to eq(64)
    end

    it "returns a valid parameterized site title" do
      SiteSetting.title = "Coding Horror"
      creator = BackupRestore::Creator.new(Discourse.system_user.id)

      expect(creator.send(:get_parameterized_title)).to eq("coding-horror")
    end
  end

  describe "#notify_user" do
    before { freeze_time Time.zone.parse("2010-01-01 12:00") }

    it "includes logs if short" do
      SiteSetting.max_export_file_size_kb = 1
      SiteSetting.export_authorized_extensions = "tar.gz"

      silence_stdout do
        creator = BackupRestore::Creator.new(Discourse.system_user.id)

        expect { creator.send(:notify_user) }.to change { Topic.private_messages.count }.by(
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
        creator = BackupRestore::Creator.new(Discourse.system_user.id)

        expect { creator.send(:notify_user) }.to change { Topic.private_messages.count }.by(
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
        creator = BackupRestore::Creator.new(Discourse.system_user.id)

        1.upto(10).each { |i| creator.send(:log, "Line #{i}") }

        expect { creator.send(:notify_user) }.to change { Topic.private_messages.count }.by(
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
