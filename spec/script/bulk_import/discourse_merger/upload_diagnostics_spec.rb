# frozen_string_literal: true

require "tmpdir"
require_relative "../../../../script/bulk_import/discourse_merger/prepared_uploads"

RSpec.describe BulkImport::DiscourseMerge::UploadDiagnostics do
  around do |example|
    Dir.mktmpdir do |dir|
      @directory = Pathname(dir)
      example.run
    end
  end

  let(:configuration) do
    data = {
      "source" => {
        "dbname" => "incoming",
      },
      "destination" => {
        "dbname" => "discourse",
      },
      "source_url" => "https://source.test",
      "destination_url" => "https://dest.test",
      "source_upload_root" => @directory.to_s,
      "upload_mode" => "preuploaded",
      "preupload_locations" => {
        "write" => "s3://hosted/review",
      },
      "reviewed_upload_target" => {
        "bucket" => "hosted",
        "prefix" => "review",
        "region" => "eu-west-1",
      },
    }
    BulkImport::DiscourseMerge::Configuration.new(@directory, contents: data.to_yaml)
  end
  let(:inventory) { instance_double(BulkImport::DiscourseMerge::Inventory) }
  let(:diagnostic) { described_class.new(configuration, inventory) }
  let(:key) { "original/1X/upload.jpeg" }
  let(:file) { @directory.join(key) }
  let(:row) do
    {
      "id" => "3594",
      "url" => "/uploads/default/#{key}",
      "filesize" => "4",
      "sha1" => Digest::SHA1.hexdigest("old!"),
    }
  end
  let(:reviewed_hash) { Digest::SHA256.hexdigest("new!") }
  let(:approval) { @directory.join("approved-originals.json") }

  before do
    file.dirname.mkpath
    file.binwrite("new!")
    pg = double(exec: nil)
    allow(inventory).to receive(:connect).and_yield(pg)
    allow(BulkImport::DiscourseMerge::SourceRows).to receive(:each) do |_, query, &consume|
      consume.call(row) if query.include?("FROM uploads")
    end
    allow(pg).to receive(:exec_params).with(/SELECT sha1/, [3594]).and_return([row])
    allow(pg).to receive(:exec_params).with(/SELECT 1/, [row["sha1"]]).and_return(
      double(ntuples: 0),
    )
  end

  def approve(hash, answer)
    diagnostic.approve("source", 3594, hash, input: StringIO.new(answer), output: StringIO.new)
  end

  it "reports both digests, sizes and path without creating approval or receipts" do
    evidence = diagnostic.enum_for(:each, "source", 3594).first
    expect(evidence).to include(
      issues: ["digest"],
      recorded_size: 4,
      actual_size: 4,
      relative_key: key,
      actual_sha1: Digest::SHA1.hexdigest("new!"),
      sha256: reviewed_hash,
    )
    expect(@directory.children.map(&:basename).map(&:to_s)).to eq(["original"])
  end

  it "requires exact bytes, size and explicit approval and produces the preparation manifest" do
    expect { approve("f" * 64, "y") }.to raise_error(/reviewed original/)
    expect { approve(reviewed_hash, "n") }.to raise_error(/cancelled/)
    expect(approval).not_to exist
    approve(reviewed_hash, "y")
    manifest =
      BulkImport::DiscourseMerge::PreparedUploads::ApprovedOriginals.new(
        @directory,
        configuration.data.fetch("reviewed_upload_target"),
      )
    expect(manifest.digest_for("source", 3594, key, row["sha1"], 4)).to eq(reviewed_hash)
    file.binwrite("longer")
    expect { approve(Digest::SHA256.file(file).hexdigest, "y") }.to raise_error(/recorded size/)
  end
end
