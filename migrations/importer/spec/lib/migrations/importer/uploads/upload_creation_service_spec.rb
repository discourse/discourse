# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::UploadCreationService do
  # The parts under test here stop before the Rails-backed `UploadCreator` call:
  # locating the source, the download error taxonomy, and the frozen result
  # builders. The actual upload creation is exercised by the integration suite.
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
  let(:downloader) { instance_double(Migrations::Importer::Uploads::FileDownloader) }
  let(:transient_errors) { [] }

  let(:status) { described_class::Status }
  let(:skip_reason) { described_class::SkipReason }
  let(:downloader_errors) { Migrations::Importer::Uploads::FileDownloader }

  describe "#create" do
    it "returns a frozen file-not-found result when the source is nowhere on disk" do
      allow(locator).to receive(:find_file_in_paths).and_return(nil)

      result = service.create({ id: "abc", filename: "a.png" }, user_id: 1)

      expect(result).to be_frozen
      expect(result.source_id).to eq("abc")
      expect(result.status).to eq(status::SKIPPED)
      expect(result.skip_reason).to eq(skip_reason::FILE_NOT_FOUND)
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

      expect(result.status).to eq(status::ERROR)
      expect(result.skip_reason).to eq(skip_reason::UPLOAD_SIZE_EXCEEDED)
      expect(result.skip_details).to eq("too big")
    end

    it "maps a download failure to the download-error skip reason" do
      allow(downloader).to receive(:download).and_raise(
        downloader_errors::DownloadFailedError.new("boom"),
      )

      result = service.create({ id: "abc", url: "https://x/a.png" }, user_id: 1)

      expect(result.status).to eq(status::ERROR)
      expect(result.skip_reason).to eq(skip_reason::DOWNLOAD_ERROR)
    end

    context "when an unexpected error escapes" do
      it "records it as a permanent error by default" do
        allow(locator).to receive(:find_file_in_paths).and_raise(RuntimeError.new("nope"))

        result = service.create({ id: "abc", filename: "a.png" }, user_id: 1)

        expect(result.status).to eq(status::ERROR)
        expect(result.skip_reason).to eq(skip_reason::ERROR)
      end

      context "when the error is transient" do
        let(:transient_errors) { [RuntimeError] }

        it "records it as too-many-retries" do
          allow(locator).to receive(:find_file_in_paths).and_raise(RuntimeError.new("flaky"))

          result = service.create({ id: "abc", filename: "a.png" }, user_id: 1)

          expect(result.skip_reason).to eq(skip_reason::TOO_MANY_RETRIES)
        end
      end
    end
  end

  describe "result builders" do
    it "freezes the error result and carries the reason" do
      result =
        service.send(
          :error_result,
          { id: "abc" },
          skip_reason: skip_reason::ERROR,
          skip_details: "why",
        )

      expect(result).to be_frozen
      expect(result).to have_attributes(
        source_id: "abc",
        status: status::ERROR,
        skip_reason: skip_reason::ERROR,
        skip_details: "why",
        upload: nil,
        markdown: nil,
        download: nil,
      )
    end
  end
end
