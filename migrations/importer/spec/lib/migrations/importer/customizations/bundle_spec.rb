# frozen_string_literal: true

require "zip"

RSpec.describe Migrations::Importer::Customizations::Bundle do
  let(:error) { Migrations::Importer::Customizations::Error }
  let(:reader_class) { Migrations::Importer::Customizations::Bundle::Reader }
  let(:writer_class) { Migrations::Importer::Customizations::Bundle::Writer }
  let(:manifest) { { "format_version" => 1, "items" => {} } }

  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  def zip_with(entries)
    path = File.join(@dir, "bundle.zip")
    Zip::OutputStream.open(path) do |zip|
      entries.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end
    path
  end

  it "round-trips uploads, theme directories and the manifest" do
    source = File.join(@dir, "logo.PNG")
    File.write(source, "image")
    theme_dir = File.join(@dir, "theme-src")
    FileUtils.mkdir_p(File.join(theme_dir, "common"))
    File.write(File.join(theme_dir, "common", "common.scss"), "a { color: red; }")
    output = File.join(@dir, "out.zip")

    paths = {}
    writer_class.open do |writer|
      paths[:upload] = writer.add_upload(source, "logo.PNG")
      paths[:same] = writer.add_upload(source, "logo.png")
      paths[:theme] = writer.add_theme_directory(theme_dir, "My Theme!")
      writer.write(output, manifest.merge("x" => paths[:upload]))
    end

    expect(paths[:upload]).to eq("uploads/#{Digest::SHA1.hexdigest("image")}.png")
    expect(paths[:same]).to eq(paths[:upload])
    expect(paths[:theme]).to eq("themes/my-theme")

    reader_class.open(output) do |reader|
      expect(reader.manifest["x"]).to eq(paths[:upload])
      expect(File.read(reader.file_path(paths[:upload], prefix: "uploads"))).to eq("image")
      dir = reader.directory_path(paths[:theme], prefix: "themes")
      expect(File.read(File.join(dir, "common", "common.scss"))).to include("red")
    end
  end

  it "rejects entries with '..' segments" do
    path = zip_with("manifest.json" => manifest.to_json, "uploads/../../evil.txt" => "x")
    expect { reader_class.open(path) { nil } }.to raise_error(error, /contains '\.\.'/)
  end

  # rubyzip refuses to write such names, so patch them in afterwards.
  it "rejects absolute entry paths" do
    path = zip_with("manifest.json" => manifest.to_json, "Xtmp/evil.txt" => "x")
    File.binwrite(path, File.binread(path).gsub("Xtmp/evil.txt", "/tmp/evil.txt"))
    expect { reader_class.open(path) { nil } }.to raise_error(error, /absolute path/)
  end

  it "rejects symlinks" do
    target = File.join(@dir, "target")
    File.write(target, "x")
    link = File.join(@dir, "link")
    File.symlink(target, link)
    path = File.join(@dir, "bundle.zip")
    Zip::File.open(path, create: true) do |zip|
      zip.get_output_stream("manifest.json") { |io| io.write(manifest.to_json) }
      zip.add("uploads/link", link)
    end

    expect { reader_class.open(path) { nil } }.to raise_error(error, /symlink/)
  end

  it "rejects manifest paths outside their directory" do
    path =
      zip_with("manifest.json" => manifest.to_json, "uploads/a.png" => "x", "secret.txt" => "x")

    reader_class.open(path) do |reader|
      expect { reader.file_path("secret.txt", prefix: "uploads") }.to raise_error(
        error,
        /Invalid bundle path/,
      )
      expect { reader.file_path("uploads/../secret.txt", prefix: "uploads") }.to raise_error(error)
      expect { reader.file_path({ "x" => 1 }, prefix: "uploads") }.to raise_error(error)
      expect { reader.directory_path("uploads/a.png", prefix: "themes") }.to raise_error(error)
    end
  end

  it "requires a supported manifest" do
    expect { reader_class.open(zip_with("other.txt" => "x")) { nil } }.to raise_error(
      error,
      /no manifest/,
    )
    path = zip_with("manifest.json" => { "format_version" => 99 }.to_json)
    expect { reader_class.open(path) { nil } }.to raise_error(error, /format_version/)
  end
end
