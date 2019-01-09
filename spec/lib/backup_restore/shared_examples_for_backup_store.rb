shared_context "backups" do
  before { create_backups }
  after(:all) { remove_backups }

  # default backup files
  let(:backup1) { BackupFile.new(filename: "b.tar.gz", size: 17, last_modified: Time.parse("2018-09-13T15:10:00Z")) }
  let(:backup2) { BackupFile.new(filename: "a.tgz", size: 29, last_modified: Time.parse("2018-02-11T09:27:00Z")) }
  let(:backup3) { BackupFile.new(filename: "r.sql.gz", size: 11, last_modified: Time.parse("2017-12-20T03:48:00Z")) }

  # backup files on another multisite
  let(:backup4) { BackupFile.new(filename: "multi-1.tar.gz", size: 22, last_modified: Time.parse("2018-11-26T03:17:09Z")) }
  let(:backup5) { BackupFile.new(filename: "multi-2.tar.gz", size: 19, last_modified: Time.parse("2018-11-27T03:16:54Z")) }
end

shared_examples "backup store" do
  it "creates the correct backup store" do
    expect(store).to be_a(expected_type)
  end

  context "without backup files" do
    describe "#files" do
      it "returns an empty array when there are no files" do
        expect(store.files).to be_empty
      end
    end

    describe "#latest_file" do
      it "returns nil when there are no files" do
        expect(store.latest_file).to be_nil
      end
    end

    describe "#stats" do
      it "works when there are no files" do
        stats = store.stats

        expect(stats[:used_bytes]).to eq(0)
        expect(stats).to have_key(:free_bytes)
        expect(stats[:count]).to eq(0)
        expect(stats[:last_backup_taken_at]).to be_nil
      end
    end
  end

  context "with backup files" do
    include_context "backups"

    describe "#files" do
      it "sorts files by last modified date in descending order" do
        expect(store.files).to eq([backup1, backup2, backup3])
      end

      it "returns only *.gz and *.tgz files" do
        files = store.files
        expect(files).to_not be_empty
        expect(files.map(&:filename)).to contain_exactly(backup1.filename, backup2.filename, backup3.filename)
      end

      it "works with multisite", type: :multisite do
        test_multisite_connection("second") do
          expect(store.files).to eq([backup5, backup4])
        end
      end
    end

    describe "#latest_file" do
      it "returns the most recent backup file" do
        expect(store.latest_file).to eq(backup1)
      end

      it "returns nil when there are no files" do
        store.files.each { |file| store.delete_file(file.filename) }
        expect(store.latest_file).to be_nil
      end

      it "works with multisite", type: :multisite do
        test_multisite_connection("second") do
          expect(store.latest_file).to eq(backup5)
        end
      end
    end

    describe "#reset_cache" do
      it "resets the storage stats report" do
        report_type = "storage_stats"
        report = Report.find(report_type)
        Report.cache(report, 35.minutes)
        expect(Report.find_cached(report_type)).to be_present

        store.reset_cache
        expect(Report.find_cached(report_type)).to be_nil
      end
    end

    describe "#delete_old" do
      it "does nothing if the number of files is <= maximum_backups" do
        SiteSetting.maximum_backups = 3

        store.delete_old
        expect(store.files).to eq([backup1, backup2, backup3])
      end

      it "deletes files starting by the oldest" do
        SiteSetting.maximum_backups = 1

        store.delete_old
        expect(store.files).to eq([backup1])
      end

      it "works with multisite", type: :multisite do
        SiteSetting.maximum_backups = 1

        test_multisite_connection("second") do
          store.delete_old
          expect(store.files).to eq([backup5])
        end
      end
    end

    describe "#file" do
      it "returns information about the file when the file exists" do
        expect(store.file(backup1.filename)).to eq(backup1)
      end

      it "returns nil when the file doesn't exist" do
        expect(store.file("foo.gz")).to be_nil
      end

      it "includes the file's source location if it is requested" do
        file = store.file(backup1.filename, include_download_source: true)
        expect(file.source).to match(source_regex("default", backup1.filename, multisite: false))
      end

      it "works with multisite", type: :multisite do
        test_multisite_connection("second") do
          file = store.file(backup4.filename, include_download_source: true)
          expect(file.source).to match(source_regex("second", backup4.filename, multisite: true))
        end
      end
    end

    describe "#delete_file" do
      it "deletes file when the file exists" do
        expect(store.files).to include(backup1)
        store.delete_file(backup1.filename)
        expect(store.files).to_not include(backup1)

        expect(store.file(backup1.filename)).to be_nil
      end

      it "does nothing when the file doesn't exist" do
        expect { store.delete_file("foo.gz") }.to_not change { store.files }
      end

      it "works with multisite", type: :multisite do
        test_multisite_connection("second") do
          expect(store.files).to include(backup5)
          store.delete_file(backup5.filename)
          expect(store.files).to_not include(backup5)
        end
      end
    end

    describe "#download_file" do
      it "downloads file to the destination" do
        filename = backup1.filename

        Dir.mktmpdir do |path|
          destination_path = File.join(path, File.basename(filename))
          store.download_file(filename, destination_path)

          expect(File.exists?(destination_path)).to eq(true)
          expect(File.size(destination_path)).to eq(backup1.size)
        end
      end

      it "raises an exception when the download fails" do
        filename = backup1.filename
        destination_path = Dir.mktmpdir { |path| File.join(path, File.basename(filename)) }

        expect { store.download_file(filename, destination_path) }.to raise_exception(StandardError)
      end

      it "works with multisite", type: :multisite do
        test_multisite_connection("second") do
          expect(store.files).to include(backup5)
          store.delete_file(backup5.filename)
          expect(store.files).to_not include(backup5)
        end
      end
    end

    describe "#stats" do
      it "returns the correct stats" do
        stats = store.stats

        expect(stats[:used_bytes]).to eq(57)
        expect(stats).to have_key(:free_bytes)
        expect(stats[:count]).to eq(3)
        expect(stats[:last_backup_taken_at]).to eq(Time.parse("2018-09-13T15:10:00Z"))
      end
    end
  end
end

shared_examples "remote backup store" do
  it "is a remote store" do
    expect(store.remote?).to eq(true)
  end

  context "with backups" do
    include_context "backups"

    describe "#upload_file" do
      def upload_file
        freeze_time

        backup = BackupFile.new(
          filename: "foo.tar.gz",
          size: 33,
          last_modified: Time.zone.now
        )

        expect(store.files).to_not include(backup)

        Tempfile.create(backup.filename) do |file|
          file.write("A" * backup.size)
          file.close

          store.upload_file(backup.filename, file.path, "application/gzip")
        end

        expect(store.files).to include(backup)
        expect(store.file(backup.filename)).to eq(backup)
      end

      it "uploads file into store" do
        upload_file
      end

      it "works with multisite", type: :multisite do
        test_multisite_connection("second") do
          upload_file
        end
      end

      it "raises an exception when a file with same filename exists" do
        Tempfile.create(backup1.filename) do |file|
          expect { store.upload_file(backup1.filename, file.path, "application/gzip") }
            .to raise_exception(BackupRestore::BackupStore::BackupFileExists)
        end
      end
    end

    describe "#generate_upload_url" do
      it "generates upload URL" do
        filename = "foo.tar.gz"
        url = store.generate_upload_url(filename)

        expect(url).to match(upload_url_regex("default", filename, multisite: false))
      end

      it "raises an exeption when a file with same filename exists" do
        expect { store.generate_upload_url(backup1.filename) }
          .to raise_exception(BackupRestore::BackupStore::BackupFileExists)
      end

      it "works with multisite", type: :multisite do
        test_multisite_connection("second") do
          filename = "foo.tar.gz"
          url = store.generate_upload_url(filename)

          expect(url).to match(upload_url_regex("second", filename, multisite: true))
        end
      end
    end
  end
end
