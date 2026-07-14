# frozen_string_literal: true

require "compression/safe_zip_reader"

RSpec.describe Compression::SafeZipReader do
  let(:temp_folder) do
    path = "#{Pathname.new(Dir.tmpdir).realpath}/#{SecureRandom.hex}"
    FileUtils.mkdir(path)
    path
  end

  let(:zip_path) { File.join(temp_folder, "archive.zip") }

  after { FileUtils.rm_rf(temp_folder) }

  def create_zip(entries)
    Zip::File.open(zip_path, create: true) do |zip_file|
      entries.each do |name, content|
        zip_file.get_output_stream(name) { |stream| stream.write(content) }
      end
    end
  end

  it "reads an entry within the configured limits" do
    create_zip("document.xml" => "hello")

    described_class.open(zip_path, max_entries: 10, max_total_bytes: 100) do |zip|
      expect(zip.read_entry("document.xml", max_bytes: 10)).to eq("hello")
      expect(zip.remaining_total_bytes).to eq(95)
    end
  end

  it "returns nil for missing entries" do
    create_zip("document.xml" => "hello")

    described_class.open(zip_path) do |zip|
      expect(zip.read_entry("missing.xml", max_bytes: 10)).to be_nil
    end
  end

  it "raises for missing required entries" do
    create_zip("document.xml" => "hello")

    described_class.open(zip_path) do |zip|
      expect { zip.read_entry("missing.xml", max_bytes: 10, required: true) }.to raise_error(
        described_class::MissingEntryError,
      )
    end
  end

  it "raises when an entry exceeds its per-entry limit" do
    create_zip("document.xml" => "hello")

    described_class.open(zip_path) do |zip|
      expect { zip.read_entry("document.xml", max_bytes: 4) }.to raise_error(
        described_class::EntryTooLargeError,
      )
    end
  end

  it "raises when reads exceed the total inflated byte budget" do
    create_zip("a.xml" => "hello", "b.xml" => "world")

    described_class.open(zip_path, max_total_bytes: 6) do |zip|
      expect(zip.read_entry("a.xml", max_bytes: 10)).to eq("hello")
      expect { zip.read_entry("b.xml", max_bytes: 10) }.to raise_error(
        described_class::EntryTooLargeError,
      )
    end
  end

  it "raises when the archive has too many entries" do
    create_zip("a.xml" => "a", "b.xml" => "b")

    expect { described_class.open(zip_path, max_entries: 1) { nil } }.to raise_error(
      described_class::TooManyEntriesError,
    )
  end

  it "streams entries to files within the configured limits" do
    create_zip("document.xml" => "hello")

    Tempfile.create("safe-zip-reader") do |tempfile|
      described_class.open(zip_path) do |zip|
        zip.stream_entry_to_file("document.xml", tempfile, max_bytes: 10)
      end

      tempfile.rewind
      expect(tempfile.read).to eq("hello")
    end
  end
end
