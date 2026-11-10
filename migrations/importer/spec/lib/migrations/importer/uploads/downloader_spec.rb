# frozen_string_literal: true

require "net/http"

RSpec.describe Migrations::Importer::Uploads::Downloader do
  subject(:downloader) { described_class.new(cache_path:, downloads:) }

  let(:cache_path) { Dir.mktmpdir }
  let(:downloads) { {} }

  after { FileUtils.remove_entry(cache_path) }

  describe "#download" do
    it "reuses a cached download when its filename is known" do
      id = "abc/123="
      path = File.join(cache_path, "abc_123-")
      File.write(path, "contents")
      downloads[id] = "image.png"

      expect(downloader.download(url: "https://example.com/image.png", id:)).to eq(
        [path, "image.png", nil],
      )
    end

    it "uses only the basename from a content disposition filename" do
      url = "https://example.com/download"
      response =
        Struct.new(:header, :content_type).new(
          { "Content-Disposition" => "attachment; filename*=UTF-8''..%5C..%5Cimage.png" },
          "image/png",
        )
      destination = Object.new
      destination.define_singleton_method(:get) do |&block|
        block.call(response, "contents", URI(url))
      end
      stub_const("FinalDestination", Class.new)
      FinalDestination.stubs(:new).with(url).returns(destination)

      _path, filename, download_record = downloader.download(url:, id: "1")

      expect(filename).to eq("image.png")
      expect(download_record[:original_filename]).to eq("image.png")
    end

    it "reports HTTP error responses as download failures" do
      url = "https://example.com/missing.png"
      response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
      destination = Object.new
      destination.define_singleton_method(:get) { |&block| block.call(response, nil, nil) }
      stub_const("FinalDestination", Class.new)
      FinalDestination.stubs(:new).with(url).returns(destination)

      expect { downloader.download(url:, id: "1") }.to raise_error(
        described_class::DownloadFailedError,
        /404.*Not Found/,
      )
    end
  end
end
