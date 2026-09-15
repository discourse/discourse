# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::Tasks::Uploader do
  # The task's DB writes go through the generated `FilesDB::*` models, and the
  # rest of the logic under test here is pure hash shaping. So we build the
  # object with `allocate` (skipping the Rails-touching constructor) and stub the
  # models — no Rails needed.
  subject(:uploader) do
    described_class.allocate.tap do |task|
      task.instance_variable_set(:@seen_upload_ids, Set.new)
      task.instance_variable_set(:@downloads, {})
      task.reporter = reporter
    end
  end

  let(:reporter) { instance_double(Migrations::Reporting::Reporter::StepHandle, notice: nil) }

  # Stands in for an ActiveRecord `Upload` without booting Rails; only `attributes`
  # is read off it.
  let(:fake_upload_class) { Data.define(:attributes) }

  let(:status) { described_class::Status }
  let(:skip_reason) { described_class::SkipReason }

  before do
    allow(Migrations::Database::FilesDB::Upload).to receive(:create)
    allow(Migrations::Database::FilesDB::UploadResult).to receive(:create)
    allow(Migrations::Database::FilesDB::Download).to receive(:create)
  end

  describe "#write (dedup by staging id)" do
    def result_for(source_id, upload_id)
      {
        id: source_id,
        status: status::OK,
        skip_reason: nil,
        skip_details: nil,
        markdown: "![](x)",
        upload: {
          id: upload_id,
          sha1: "abc",
          url: "//x.png",
          filesize: 1,
          original_filename: "x.png",
        },
        download: nil,
      }
    end

    it "inserts the uploads row once per staging id but records every result" do
      seen = []
      allow(Migrations::Database::FilesDB::Upload).to receive(:create) { |**kwargs|
        seen << kwargs[:id]
      }

      uploader.write(result_for("hash-1", 42))
      uploader.write(result_for("hash-2", 42))
      uploader.write(result_for("hash-3", 43))

      expect(seen).to eq([42, 43])
      expect(Migrations::Database::FilesDB::UploadResult).to have_received(:create).with(
        hash_including(id: "hash-2", upload_id: 42),
      )
    end
  end

  describe "#write" do
    it "records the uploads row and the ok result, returning :ok" do
      result = {
        id: "hash-ok",
        status: status::OK,
        skip_reason: nil,
        skip_details: nil,
        markdown: "![](x)",
        upload: {
          id: 7,
          sha1: "abc",
          url: "//x.png",
          filesize: 1,
          original_filename: "x.png",
        },
        download: nil,
      }

      expect(uploader.write(result)).to eq(:ok)

      expect(Migrations::Database::FilesDB::Upload).to have_received(:create).with(
        hash_including(id: 7),
      )
      expect(Migrations::Database::FilesDB::UploadResult).to have_received(:create).with(
        id: "hash-ok",
        status: status::OK,
        skip_reason: nil,
        skip_details: nil,
        markdown: "![](x)",
        upload_id: 7,
      )
    end

    it "records the error result with a null upload_id and reports it" do
      result = {
        id: "hash-err",
        status: status::ERROR,
        skip_reason: skip_reason::DOWNLOAD_ERROR,
        skip_details: "boom",
        markdown: nil,
        upload: nil,
        download: nil,
      }

      expect(uploader.write(result)).to eq(:error)

      expect(Migrations::Database::FilesDB::Upload).not_to have_received(:create)
      expect(Migrations::Database::FilesDB::UploadResult).to have_received(:create).with(
        hash_including(id: "hash-err", status: status::ERROR, upload_id: nil),
      )
      expect(reporter).to have_received(:notice)
    end

    it "records a download row when the result carries one" do
      result = {
        id: "hash-dl",
        status: status::SKIPPED,
        skip_reason: skip_reason::FILE_NOT_FOUND,
        skip_details: nil,
        markdown: nil,
        upload: nil,
        download: {
          id: "hash-dl",
          original_filename: "x.png",
        },
      }

      expect(uploader.write(result)).to eq(:skip)

      expect(Migrations::Database::FilesDB::Download).to have_received(:create).with(
        id: "hash-dl",
        original_filename: "x.png",
      )
    end
  end
end
