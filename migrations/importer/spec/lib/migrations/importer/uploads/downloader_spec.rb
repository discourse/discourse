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

    it "waits for an active cache lookup before updating the cache" do
      read_started = Queue.new
      finish_read = Queue.new
      values = { "abc" => "old.png" }
      downloads =
        Object.new.tap do |cache|
          cache.define_singleton_method(:[]) do |id|
            read_started << true
            finish_read.pop
            values[id]
          end
          cache.define_singleton_method(:[]=) { |id, filename| values[id] = filename }
        end
      downloader = described_class.new(cache_path:, downloads:)
      path = File.join(cache_path, "abc")
      File.write(path, "contents")

      reader = Thread.new { downloader.download(url: "https://example.com/image.png", id: "abc") }
      read_started.pop
      writer_started = Queue.new
      writer =
        Thread.new do
          writer_started << true
          downloader.remember("abc", "image.png")
        end
      writer_started.pop

      begin
        expect(writer.join(0.1)).to be_nil
      ensure
        finish_read << true
      end
      reader.join

      expect(writer.value).to eq("image.png")
    end
  end
end
