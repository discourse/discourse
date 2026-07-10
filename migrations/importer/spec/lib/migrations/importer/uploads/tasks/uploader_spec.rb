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
  FakeUpload = Data.define(:attributes)

  let(:status) { described_class::Status }
  let(:skip_reason) { described_class::SkipReason }

  before do
    allow(Migrations::Database::FilesDB::Upload).to receive(:create)
    allow(Migrations::Database::FilesDB::UploadResult).to receive(:create)
    allow(Migrations::Database::FilesDB::Download).to receive(:create)
  end

  describe "result builders" do
    it "builds a file-not-found skip result" do
      result = uploader.send(:missing_result, { id: "abc" })

      expect(result).to include(
        id: "abc",
        status: status::SKIPPED,
        skip_reason: skip_reason::FILE_NOT_FOUND,
        markdown: nil,
        upload: nil,
        download: nil,
      )
    end

    it "builds an error result carrying the reason and details" do
      result =
        uploader.send(
          :error_result,
          { id: "abc" },
          skip_reason: skip_reason::DOWNLOAD_ERROR,
          skip_details: "boom",
          download: nil,
        )

      expect(result).to include(
        id: "abc",
        status: status::ERROR,
        skip_reason: skip_reason::DOWNLOAD_ERROR,
        skip_details: "boom",
        upload: nil,
      )
    end
  end

  describe "#upload_attributes" do
    it "slices the upload down to the columns the files DB keeps" do
      upload =
        FakeUpload.new(
          attributes: {
            "id" => 7,
            "sha1" => "deadbeef",
            "url" => "//example/x.png",
            "filesize" => 10,
            "original_filename" => "x.png",
            "user_id" => 5,
            "updated_at" => "2026-01-01",
            "retain_hours" => 3,
          },
        )

      attributes = uploader.send(:upload_attributes, upload)

      expect(attributes).to include(id: 7, sha1: "deadbeef", url: "//example/x.png")
      expect(attributes.keys).not_to include(:user_id, :updated_at, :retain_hours)
    end
  end

  describe "#outcome_for" do
    it "maps the result status onto the progress outcome" do
      expect(uploader.send(:outcome_for, status::OK)).to eq(:ok)
      expect(uploader.send(:outcome_for, status::SKIPPED)).to eq(:skip)
      expect(uploader.send(:outcome_for, status::ERROR)).to eq(:error)
    end
  end

  describe "#write_upload (dedup by staging id)" do
    let(:attributes) do
      { id: 42, sha1: "abc", url: "//x.png", filesize: 1, original_filename: "x.png" }
    end

    it "inserts the uploads row once per staging id and always returns the id" do
      seen = []
      allow(Migrations::Database::FilesDB::Upload).to receive(:create) { |**kwargs|
        seen << kwargs[:id]
      }

      expect(uploader.send(:write_upload, attributes)).to eq(42)
      expect(uploader.send(:write_upload, attributes)).to eq(42)
      expect(uploader.send(:write_upload, attributes.merge(id: 43))).to eq(43)

      expect(seen).to eq([42, 43])
    end

    it "writes nothing and returns nil when there is no upload" do
      expect(uploader.send(:write_upload, nil)).to be_nil
      expect(Migrations::Database::FilesDB::Upload).not_to have_received(:create)
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
