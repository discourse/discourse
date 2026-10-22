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
          extension = with_uploads ? "tar.gz" : "sql.gz"

          expect(creator.instance_variable_get(:@backup_filename)).to eq(
            "my-forum-2026-09-25-120000-v2026-9-0-latest-20260923080644.#{extension}",
          )
        end
      end
    end
  end

  describe "#pg_dump_command" do
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
      it "downloads files with GET requests and no HEAD requests with #{concurrency} workers" do
        GlobalSetting.stubs(:backup_s3_download_concurrency).returns(concurrency)
        2.times do |index|
          Fabricate(:upload, url: "//bucket.s3.amazonaws.com/original/1X/file#{index}.png")
        end
        client = Aws::S3::Client.new(stub_responses: true)
        client.stub_responses(:get_object, body: "file contents", content_length: 13)
        S3Helper.any_instance.stubs(:s3_client).returns(client)

        tmp_dir = archive_remote_uploads

        2.times do |index|
          path = File.join(tmp_dir, Discourse.store.upload_path, "original/1X/file#{index}.png")
          expect(File.read(path)).to eq("file contents")
        end
        operations = client.api_requests.map { |request| request[:operation_name] }
        expect(operations.count(:get_object)).to eq(2)
        expect(operations).not_to include(:head_object)
      end

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

        it "continues downloading other uploads when a file is missing from S3" do
          missing = Fabricate(:upload, url: "//bucket.s3.amazonaws.com/original/1X/missing.png")
          Fabricate(:upload, url: "//bucket.s3.amazonaws.com/original/1X/present.png")
          store = FileStore::S3Store.new
          store.define_singleton_method(:download_file) do |upload, filename, **_options|
            raise "No such key" if upload.id == missing.id
            File.write(filename, "file contents")
          end
          FileStore::S3Store.stubs(:new).returns(store)

          tmp_dir = archive_remote_uploads

          path = File.join(tmp_dir, Discourse.store.upload_path, "original/1X/present.png")
          expect(File.read(path)).to eq("file contents")
          expect(creator.instance_variable_get(:@download_stats)[:downloaded]).to eq(1)
          expect(creator.instance_variable_get(:@logs).join).to include(
            "Failed to download file with upload ID #{missing.id}",
          )
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

        it "starts new copies for large duplicate groups without downloading again" do
          uploads =
            5.times.map do |id|
              described_class::UploadData.new(
                id: id,
                url: "//bucket/#{id}",
                sha1: "shared",
                extension: "txt",
                original_filename: "#{id}.txt",
              )
            end
          # Repeated paths must not count toward the link limit or overwrite a target.
          creator.stubs(:group_remote_uploads_by_sha1).returns(
            "shared" => [uploads.first, *uploads],
          )
          store = FileStore::S3Store.new
          FileStore::S3Store.stubs(:new).returns(store)
          store.define_singleton_method(:get_path_for_upload) do |upload|
            "original/#{upload.id}.txt"
          end
          store
            .expects(:download_file)
            .once
            .with do |_upload, filename, **_options|
              File.write(filename, "shared contents")
              true
            end

          extracted = nil
          stub_const(BackupRestore::ArchiveWriter, "MAX_LINKS", 2) do
            extracted = archive_remote_uploads
          end
          paths =
            uploads.map do |upload|
              File.join(extracted, Discourse.store.upload_path, "original/#{upload.id}.txt")
            end
          expect(paths.map { |path| File.read(path) }).to eq(["shared contents"] * 5)
          inodes = paths.map { |path| File.stat(path).ino }
          expect(inodes[0]).to eq(inodes[1])
          expect(inodes[2]).to eq(inodes[3])
          expect(inodes.values_at(0, 2, 4).uniq.size).to eq(3)
          expect(creator.instance_variable_get(:@download_stats)).to include(
            downloaded: 1,
            hardlinked: 2,
            copied: 2,
          )
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
          store.define_singleton_method(:download_file) do |_upload, filename, **_options|
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
    let(:creator) { described_class.new(nil) }

    around do |example|
      Dir.mktmpdir do |directory|
        @directory = directory
        @staging = File.join(directory, "staging")
        @local_uploads = File.join(directory, Discourse.store.upload_path)
        FileUtils.mkdir_p([@staging, @local_uploads])
        @dump = File.join(@staging, BackupRestore::DUMP_FILE)
        Zlib::GzipWriter.open(@dump) { |io| io.write("SELECT 1;\n") }
        creator.instance_variable_set(:@tmp_directory, @staging)
        creator.instance_variable_set(:@dump_filename, @dump)
        creator.instance_variable_set(:@archive_basename, File.join(directory, "backup"))
        creator.instance_variable_set(:@local_uploads_directory, @local_uploads)
        example.run
      end
    end

    [true, false].each do |include_thumbnails|
      it "creates a compatible gzip archive with thumbnails #{include_thumbnails}" do
        Rails.stubs(:public_path).returns(Pathname.new(@directory))
        SiteSetting.include_thumbnails_in_backups = include_thumbnails
        FileUtils.mkdir_p(File.join(@local_uploads, "optimized"))
        File.write(File.join(@local_uploads, "file.txt"), "local upload")
        File.write(File.join(@local_uploads, "optimized", "thumb.txt"), "thumbnail")
        File.symlink("file.txt", File.join(@local_uploads, "link.txt"))
        File.link(File.join(@local_uploads, "file.txt"), File.join(@local_uploads, "hardlink.txt"))

        creator.send(:create_archive)

        archive = File.join(@directory, "backup.tar.gz")
        Discourse::Utils.execute_command("gzip", "-t", archive)
        expect(File.exist?(File.join(@directory, "backup.tar"))).to eq(false)
        expect(File.exist?("#{archive}.partial")).to eq(false)
        expect(File.exist?(@staging)).to eq(false)

        # Exercise the same decompression and dump discovery used by restore.
        handler = BackupRestore::BackupFileHandler.new(stub(log: nil), "backup.tar.gz", "default")
        extracted = File.join(@directory, "extracted")
        FileUtils.mkdir_p(extracted)
        handler.instance_variable_set(:@archive_path, archive)
        handler.instance_variable_set(:@tmp_directory, extracted)
        handler.send(:decompress_archive)
        dump = handler.send(:extract_db_dump)
        expect(File.read(dump)).to eq("SELECT 1;\n")
        uploads = File.join(extracted, Discourse.store.upload_path)
        expect(File.read(File.join(uploads, "file.txt"))).to eq("local upload")
        expect(File.read(File.join(uploads, "link.txt"))).to eq("local upload")
        expect(File.symlink?(File.join(uploads, "link.txt"))).to eq(false)
        expect(File.stat(File.join(uploads, "hardlink.txt")).ino).to eq(
          File.stat(File.join(uploads, "file.txt")).ino,
        )
        expect(File.exist?(File.join(uploads, "optimized", "thumb.txt"))).to eq(include_thumbnails)
        expect(File.read(File.join(@local_uploads, "file.txt"))).to eq("local upload")
      end
    end

    it "skips dangling symlinks and still produces a readable backup" do
      File.symlink("missing", File.join(@local_uploads, "dangling"))
      File.write(File.join(@local_uploads, "present.txt"), "contents")

      creator.send(:create_archive)

      extracted = File.join(@directory, "extracted")
      FileUtils.mkdir_p(extracted)
      Discourse::Utils.execute_command(
        "tar",
        "-xzf",
        File.join(@directory, "backup.tar.gz"),
        "-C",
        extracted,
      )
      expect(File.read(File.join(extracted, Discourse.store.upload_path, "present.txt"))).to eq(
        "contents",
      )
      expect(creator.instance_variable_get(:@logs).join).to include(
        "Skipping missing local upload:",
        "dangling",
      )
    end

    it "skips a file removed between stat and opening it without writing a header" do
      source = File.join(@local_uploads, "removed.txt")
      File.write(source, "contents")
      io = StringIO.new
      archive = BackupRestore::ArchiveWriter.new(io)
      archive.define_singleton_method(:add_file) do |filename, name|
        File.unlink(filename)
        super(filename, name)
      end
      creator.instance_variable_set(:@archive, archive)

      creator.send(:add_path_to_archive, source, "removed.txt")

      expect(io.string).to be_empty
      expect(creator.instance_variable_get(:@logs).join).to include(
        "Skipping missing local upload:",
        "removed.txt",
      )
    end

    it "archives remote downloads through gzip and removes staging" do
      setup_s3
      SiteSetting.include_s3_uploads_in_backups = true
      GlobalSetting.stubs(:backup_s3_download_concurrency).returns(2)
      uploads =
        4.times.map do |i|
          Fabricate(:upload, url: "//bucket.s3.amazonaws.com/original/1X/#{i}.png")
        end
      Fabricate(
        :upload,
        url: "//bucket.s3.amazonaws.com/original/1X/duplicate.png",
        original_sha1: uploads.first.sha1,
      )
      client = Aws::S3::Client.new(stub_responses: true)
      client.stub_responses(:get_object, body: "remote file", content_length: 11)
      S3Helper.any_instance.stubs(:s3_client).returns(client)

      creator.send(:create_archive)

      extracted = File.join(@directory, "extracted")
      FileUtils.mkdir_p(extracted)
      Discourse::Utils.execute_command(
        "tar",
        "-xzf",
        File.join(@directory, "backup.tar.gz"),
        "-C",
        extracted,
      )
      4.times do |i|
        path = File.join(extracted, Discourse.store.upload_path, "original/1X/#{i}.png")
        expect(File.read(path)).to eq("remote file")
      end
      upload_directory = File.join(extracted, Discourse.store.upload_path, "original/1X")
      expect(File.stat(File.join(upload_directory, "duplicate.png")).ino).to eq(
        File.stat(File.join(upload_directory, "0.png")).ino,
      )
      expect(File.exist?(@staging)).to eq(false)
    end

    [RuntimeError, SystemExit].each do |error|
      it "removes the partial archive and waits for gzip when interrupted by #{error}" do
        creator.stubs(:add_local_uploads_to_archive).raises(error)
        expect { creator.send(:create_archive) }.to raise_error(error)
        expect(Dir.glob(File.join(@directory, "backup*"))).to be_empty
        expect(creator.instance_variable_get(:@archive)).to be_nil
        expect($?.success?).to eq(true)
      end
    end

    it "does not publish an archive when gzip fails" do
      SiteSetting.stubs(:backup_gzip_compression_level_for_uploads).returns("invalid")
      expect { creator.send(:create_archive) }.to raise_error(
        StandardError,
        /Failed to gzip archive.*gzip: invalid option/m,
      )
      expect(Dir.glob(File.join(@directory, "backup*"))).to be_empty
    end
  end

  describe "gzip exiting while an archive is being written" do
    it "reports stderr instead of a broken pipe and removes the partial archive" do
      Dir.mktmpdir do |directory|
        gzip = File.join(directory, "gzip")
        File.write(
          gzip,
          "#!/bin/sh\nhead -c 16 >/dev/null\necho 'gzip: No space left on device' >&2\nexit 1\n",
        )
        File.chmod(0o755, gzip)
        dump = File.join(directory, "dump.sql.gz")
        File.write(dump, "x" * 1.megabyte)
        creator = described_class.new(nil)
        creator.instance_variable_set(:@tmp_directory, directory)
        creator.instance_variable_set(:@dump_filename, dump)
        creator.instance_variable_set(:@archive_basename, File.join(directory, "backup"))
        original_path = ENV["PATH"]
        begin
          ENV["PATH"] = "#{directory}:#{original_path}"
          expect { creator.send(:create_archive) }.to raise_error(
            /Failed to gzip archive \(exit status 1\).*No space left on device/m,
          )
        ensure
          ENV["PATH"] = original_path
        end
        expect(Dir.glob(File.join(directory, "backup*"))).to be_empty
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
