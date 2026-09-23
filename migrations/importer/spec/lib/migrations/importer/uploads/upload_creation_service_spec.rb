# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::UploadCreationService do
  # `UploadCreator` needs Rails, so these tests use a fake one where they get
  # that far.
  subject(:service) do
    described_class.new(
      locator:,
      downloader:,
      discourse_store: nil,
      retry_policy: Migrations::Importer::Uploads::RetryPolicy.new(transient_errors:),
    )
  end

  let(:locator) do
    instance_double(Migrations::Importer::Uploads::SourceFileLocator, find_file_in_paths: nil)
  end
  let(:downloader) { instance_double(Migrations::Importer::Uploads::Downloader) }
  let(:transient_errors) { [] }

  let(:enums) { Migrations::Database::FilesDB::Enums }
  let(:downloader_errors) { Migrations::Importer::Uploads::Downloader }

  describe "#create" do
    it "returns a frozen file-not-found result when the source is nowhere on disk" do
      allow(locator).to receive(:find_file_in_paths).and_return(nil)

      result = service.create({ id: "abc", filename: "a.png" }, user_id: 1)

      expect(result).to be_frozen
      expect(result.source_id).to eq("abc")
      expect(result.status).to eq(enums::UploadResultStatus::SKIPPED)
      expect(result.skip_reason).to eq(enums::UploadSkipReason::FILE_NOT_FOUND)
      expect(result.upload).to be_nil
    end

    it "drops a URL row with nothing to download" do
      allow(downloader).to receive(:download).and_return(nil)

      result = service.create({ id: "abc", url: "https://x/a.png" }, user_id: 1)

      expect(result).to be_nil
    end

    it "maps a size overrun to the upload-size-exceeded skip reason" do
      allow(downloader).to receive(:download).and_raise(
        downloader_errors::UploadSizeExceededError.new("too big"),
      )

      result = service.create({ id: "abc", url: "https://x/a.png" }, user_id: 1)

      expect(result.status).to eq(enums::UploadResultStatus::ERROR)
      expect(result.skip_reason).to eq(enums::UploadSkipReason::UPLOAD_SIZE_EXCEEDED)
      expect(result.skip_details).to eq("too big")
    end

    it "maps a download failure to the download-error skip reason" do
      allow(downloader).to receive(:download).and_raise(
        downloader_errors::DownloadFailedError.new("boom"),
      )

      result = service.create({ id: "abc", url: "https://x/a.png" }, user_id: 1)

      expect(result.status).to eq(enums::UploadResultStatus::ERROR)
      expect(result.skip_reason).to eq(enums::UploadSkipReason::DOWNLOAD_ERROR)
    end

    context "when the upload creator runs" do
      let(:creator_class) do
        Class.new do
          class << self
            attr_accessor :filenames, :running, :max_running

            def reset!
              @filenames = Queue.new
              @running = 0
              @max_running = 0
              @counter_lock = Mutex.new
            end

            def track
              @counter_lock.synchronize do
                @running += 1
                @max_running = [@max_running, @running].max
              end
              sleep(0.05)
            ensure
              @counter_lock.synchronize { @running -= 1 }
            end
          end

          def initialize(_file, filename, type:, origin:)
            self.class.filenames << filename
          end

          def create_for(_user_id)
            self.class.track
            Struct.new(:persisted?, :errors).new(
              false,
              Struct.new(:full_messages).new(["not saved"]),
            )
          end
        end
      end

      around do |example|
        Dir.mktmpdir do |dir|
          @dir = dir
          example.run
        end
      end

      before do
        creator_class.reset!
        stub_const("UploadCreator", creator_class)
        stub_const("ActiveRecord::RecordNotUnique", Class.new(StandardError))
      end

      def source_file(name, content)
        path = File.join(@dir, name)
        File.write(path, content)
        path
      end

      it "names the upload after the row's filename" do
        allow(locator).to receive(:find_file_in_paths).and_return(source_file("a", "bytes"))

        result = service.create({ id: "abc", filename: "photo.png", path: "a" }, user_id: 1)

        expect(creator_class.filenames.pop).to eq("photo.png")
        expect(result.skip_details).to eq("not saved")
      end

      it "does not create two uploads with the same content at the same time" do
        first = source_file("first.png", "same bytes")
        second = source_file("second.png", "same bytes")
        allow(locator).to receive(:find_file_in_paths) { |row| row[:path] }

        [first, second].map do |path|
            Thread.new { service.create({ id: path, filename: "a.png", path: }, user_id: 1) }
          end
          .each(&:join)

        expect(creator_class.filenames.size).to eq(2)
        expect(creator_class.max_running).to eq(1)
      end
    end

    context "when an unexpected error escapes" do
      it "records it as a frozen permanent error by default" do
        allow(locator).to receive(:find_file_in_paths).and_raise(RuntimeError.new("nope"))

        result = service.create({ id: "abc", filename: "a.png" }, user_id: 1)

        expect(result).to be_frozen
        expect(result).to have_attributes(
          source_id: "abc",
          status: enums::UploadResultStatus::ERROR,
          skip_reason: enums::UploadSkipReason::ERROR,
          skip_details: "nope",
          upload: nil,
          markdown: nil,
          download: nil,
        )
      end

      context "when the error is transient" do
        let(:transient_errors) { [RuntimeError] }

        it "records it as too-many-retries" do
          allow(locator).to receive(:find_file_in_paths).and_raise(RuntimeError.new("flaky"))

          result = service.create({ id: "abc", filename: "a.png" }, user_id: 1)

          expect(result.skip_reason).to eq(enums::UploadSkipReason::TOO_MANY_RETRIES)
        end
      end
    end
  end
end
