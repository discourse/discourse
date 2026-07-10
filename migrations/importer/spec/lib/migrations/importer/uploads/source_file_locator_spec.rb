# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::SourceFileLocator do
  around do |example|
    Dir.mktmpdir do |dir|
      @dir = dir
      example.run
    end
  end

  def touch(relative)
    path = File.join(@dir, relative)
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)
    path
  end

  describe "#find_file_in_paths" do
    it "finds a file directly under a root path" do
      expected = touch("uploads/a.png")
      locator = described_class.new(root_paths: [File.join(@dir, "uploads")])

      expect(locator.find_file_in_paths({ filename: "a.png" })).to eq(expected)
    end

    it "honors the row's relative path" do
      expected = touch("uploads/sub/dir/a.png")
      locator = described_class.new(root_paths: [File.join(@dir, "uploads")])

      path = locator.find_file_in_paths({ filename: "a.png", relative_path: "sub/dir" })
      expect(path).to eq(expected)
    end

    it "tries each root in order and returns the first hit" do
      expected = touch("second/a.png")
      locator =
        described_class.new(root_paths: [File.join(@dir, "first"), File.join(@dir, "second")])

      expect(locator.find_file_in_paths({ filename: "a.png" })).to eq(expected)
    end

    it "applies path replacements when the verbatim path misses" do
      expected = touch("uploads/new/a.png")
      locator =
        described_class.new(
          root_paths: [File.join(@dir, "uploads")],
          path_replacements: [%w[old new]],
        )

      path = locator.find_file_in_paths({ filename: "a.png", relative_path: "old" })
      expect(path).to eq(expected)
    end

    it "returns nil when nothing matches" do
      locator = described_class.new(root_paths: [File.join(@dir, "uploads")])

      expect(locator.find_file_in_paths({ filename: "missing.png" })).to be_nil
    end
  end

  describe "#tempfile_from_data" do
    it "writes the blob to a rewound binary tempfile the caller owns" do
      locator = described_class.new(root_paths: [])

      file = locator.tempfile_from_data("\x00binary\xFF".b)
      begin
        expect(File.binread(file.path)).to eq("\x00binary\xFF".b)
        expect(file.pos).to eq(0)
      ensure
        file.close!
      end
    end
  end
end
