# frozen_string_literal: true

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
  end

  describe "#remember" do
    it "makes a newly recorded download available to later lookups" do
      id = "abc"
      path = File.join(cache_path, id)
      File.write(path, "contents")

      downloader.remember(id, "image.png")

      expect(downloader.download(url: "https://example.com/image.png", id:)).to eq(
        [path, "image.png", nil],
      )
    end
  end
end
