# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::FileDownloader do
  around do |example|
    Dir.mktmpdir do |dir|
      @cache = dir
      example.run
    end
  end

  describe "#download (cache hit)" do
    it "returns the cached file and no record when the store knows the filename" do
      # `disco upload` backs the store with the files DB; inline mode with a plain
      # Hash. Either way a download id already on disk with a known filename must
      # not be re-fetched, so this never touches the network.
      cached_path = File.join(@cache, "id-1")
      File.binwrite(cached_path, "x")

      downloader = described_class.new(cache_path: @cache, filename_store: { "id-1" => "a.png" })

      result = downloader.download(url: "https://example.com/a.png", id: "id-1")

      expect(result.path).to eq(cached_path)
      expect(result.filename).to eq("a.png")
      expect(result.record).to be_nil
    end

    it "sanitizes the id into the cache path" do
      downloader = described_class.new(cache_path: @cache, filename_store: {})

      path = downloader.send(:cache_path_for, "a/b=c")

      expect(path).to eq(File.join(@cache, "a_b-c"))
    end
  end

  describe "error taxonomy" do
    it "defines the #33546 size overrun as a kind of download failure" do
      expect(described_class::UploadSizeExceededError.ancestors).to include(
        described_class::DownloadFailedError,
      )
    end
  end
end
