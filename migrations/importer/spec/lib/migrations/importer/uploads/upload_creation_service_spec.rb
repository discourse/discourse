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

    it "maps download failures to their skip reasons" do
      {
        downloader_errors::UploadSizeExceededError => enums::UploadSkipReason::UPLOAD_SIZE_EXCEEDED,
        downloader_errors::DownloadFailedError => enums::UploadSkipReason::DOWNLOAD_ERROR,
      }.each do |error_class, skip_reason|
        allow(downloader).to receive(:download).and_raise(error_class.new("boom"))

        result = service.create({ id: "abc", url: "https://x/a.png" }, user_id: 1)

        expect(result).to have_attributes(
          status: enums::UploadResultStatus::ERROR,
          skip_reason:,
          skip_details: "boom",
        )
      end
    end

    context "when the upload creator runs" do
      # Records each create. When `hold` is set, a create waits on it until the
      # test lets it continue.
      let(:creator_class) do
        Class.new do
          class << self
            attr_accessor :filenames, :started, :hold
          end

          def initialize(_file, filename, type:, origin:)
            self.class.filenames << filename
          end

          def create_for(_user_id)
            self.class.started << true
            self.class.hold&.pop
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
        creator_class.filenames = Queue.new
        creator_class.started = Queue.new
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
        creator_class.hold = Queue.new
        paths = [source_file("first.png", "same bytes"), source_file("second.png", "same bytes")]
        allow(locator).to receive(:find_file_in_paths) { |row| row[:path] }

        threads =
          paths.map do |path|
            Thread.new { service.create({ id: path, filename: "a.png", path: }, user_id: 1) }
          end
        creator_class.started.pop
        wait_until { threads.all? { |thread| thread.status == "sleep" } }

        expect(creator_class.started).to be_empty

        2.times { creator_class.hold << :go }
        threads.each(&:join)
        expect(creator_class.started.size).to eq(1)
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
