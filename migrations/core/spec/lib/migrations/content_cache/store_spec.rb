# frozen_string_literal: true

RSpec.describe Migrations::ContentCache::Store do
  around do |example|
    Dir.mktmpdir do |directory|
      @path = File.join(directory, "cache.db")
      example.run
    end
  end

  it "publishes a standalone database with exact identity and content matching" do
    described_class.write(@path, { "urls" => { "site" => "https://source.test" } }) do |store|
      store.put("post", "001", described_class.digest("hello"), { "cooked" => "<p>hello</p>" })
    end
    FileUtils.cp(@path, "#{@path}.copy")
    store = described_class.new("#{@path}.copy")
    expect(store.get("post", "001", described_class.digest("hello"))).to eq(
      "cooked" => "<p>hello</p>",
    )
    expect(store.get("post", "1", described_class.digest("hello"))).to be_nil
    expect(store.get("post", "001", described_class.digest("hello "))).to be_nil
    expect(store.metadata["urls"]).to eq("site" => "https://source.test")
  ensure
    store&.close
  end

  it "keeps the previous export when a new export fails" do
    described_class.write(@path, {}) do |store|
      store.put("post", "1", "hash", { "value" => "old" })
    end
    expect do
      described_class.write(@path, {}) do |store|
        store.put("post", "1", "hash", { "value" => "new" })
        raise "interrupted"
      end
    end.to raise_error("interrupted")
    store = described_class.new(@path)
    expect(store.get("post", "1", "hash")).to eq("value" => "old")
  ensure
    store&.close
  end

  it "rejects missing and unsupported databases" do
    expect { described_class.new(@path) }.to raise_error(ArgumentError, /not found/)
    described_class.write(@path, {}) { |store| }
    Migrations::Database.connect(@path) do |connection|
      connection.execute("UPDATE metadata SET value = '999' WHERE key = 'format_version'")
    end
    expect { described_class.new(@path) }.to raise_error(ArgumentError, /Unsupported/)
  end
end
