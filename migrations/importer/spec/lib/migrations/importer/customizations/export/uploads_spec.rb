# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::Export::Uploads, :rails do
  subject(:uploads) { described_class.new(writer, base_url:) }

  let(:writer) { instance_double(Migrations::Importer::Customizations::Bundle::Writer) }
  let(:base_url) { nil }
  let(:downloaded) { Tempfile.new("download") }

  before { allow(writer).to receive(:add_upload).and_return("uploads/file.png") }
  after { downloaded.close! }

  def missing_upload(url)
    Fabricate(:upload, original_filename: "logo.png", url:)
  end

  it "downloads absolute URLs without a base URL" do
    upload = missing_upload("https://cdn.example.com/original/1X/logo.png")
    allow(FileHelper).to receive(:download).and_return(downloaded)

    expect(uploads.ref(upload)).to include("upload" => "uploads/file.png")
    expect(FileHelper).to have_received(:download).with(
      "https://cdn.example.com/original/1X/logo.png",
      a_hash_including(follow_redirect: true),
    )
  end

  it "downloads scheme-less URLs over https" do
    upload = missing_upload("//bucket.s3.amazonaws.com/original/1X/logo.png")
    allow(FileHelper).to receive(:download).and_return(downloaded)

    uploads.ref(upload)

    expect(FileHelper).to have_received(:download).with(
      "https://bucket.s3.amazonaws.com/original/1X/logo.png",
      a_hash_including(follow_redirect: true),
    )
  end

  it "asks for --upload-base-url when a relative URL can't be found locally" do
    upload = missing_upload("/uploads/default/original/1X/logo.png")

    expect { uploads.ref(upload) }.to raise_error(
      Migrations::Importer::Customizations::Error,
      /pass --upload-base-url/,
    )
  end

  context "with a base URL" do
    let(:base_url) { "https://site.example.com/" }

    it "downloads relative URLs from that site" do
      upload = missing_upload("/uploads/default/original/1X/logo.png")
      allow(FileHelper).to receive(:download).and_return(downloaded)

      uploads.ref(upload)

      expect(FileHelper).to have_received(:download).with(
        "https://site.example.com/uploads/default/original/1X/logo.png",
        a_hash_including(follow_redirect: true),
      )
    end

    it "names the URL when the download fails" do
      upload = missing_upload("/uploads/default/original/1X/logo.png")
      allow(FileHelper).to receive(:download).and_return(nil)

      expect { uploads.ref(upload) }.to raise_error(
        Migrations::Importer::Customizations::Error,
        %r{download from https://site\.example\.com/uploads/default/original/1X/logo\.png failed},
      )
    end
  end
end
