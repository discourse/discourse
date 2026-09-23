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

  def find(filename:, path:, roots: ["uploads"], path_replacements: [])
    root_paths = roots.map { |root| File.join(@dir, root) }
    described_class.new(root_paths:, path_replacements:).find_file_in_paths({ filename:, path: })
  end

  describe "#find_file_in_paths" do
    it "finds the recorded path under a root path" do
      expected = touch("uploads/sub/dir/a.png")

      expect(find(filename: "a.png", path: "sub/dir/a.png")).to eq(expected)
    end

    it "finds an absolute-looking recorded path under a root path" do
      expected = touch("uploads/original/1X/abc.png")

      expect(find(filename: "photo.png", path: "/original/1X/abc.png")).to eq(expected)
    end

    it "tries each root in order and returns the first hit" do
      expected = touch("second/a.png")

      expect(find(filename: "a.png", path: "a.png", roots: %w[first second])).to eq(expected)
    end

    it "applies path replacements when the recorded path misses" do
      expected = touch("uploads/new/a.png")

      expect(find(filename: "a.png", path: "old/a.png", path_replacements: [%w[old new]])).to eq(
        expected,
      )
    end

    it "looks up the filename directly under a root when the row has no path" do
      expected = touch("uploads/a.png")

      expect(find(filename: "a.png", path: nil)).to eq(expected)
    end

    it "does not return a directory" do
      FileUtils.mkdir_p(File.join(@dir, "uploads", "a.png"))

      expect(find(filename: "a.png", path: "a.png")).to be_nil
    end

    it "refuses a recorded path that escapes the root" do
      touch("secret.txt")
      touch("uploads/other.png")

      expect(find(filename: "x", path: "../secret.txt")).to be_nil
    end

    it "refuses an absolute recorded path outside the root" do
      secret = touch("secret.txt")
      touch("uploads/other.png")

      expect(find(filename: "x", path: secret)).to be_nil
    end

    it "refuses a symlink that points outside the root" do
      secret = touch("secret.txt")
      FileUtils.mkdir_p(File.join(@dir, "uploads"))
      File.symlink(secret, File.join(@dir, "uploads", "link.png"))

      expect(find(filename: "link.png", path: "link.png")).to be_nil
    end

    it "follows a symlink that stays inside the root" do
      target = touch("uploads/real/a.png")
      File.symlink(target, File.join(@dir, "uploads", "a.png"))

      expect(find(filename: "a.png", path: "a.png")).to eq(target)
    end

    it "refuses a filename with directory parts when the row has no path" do
      touch("secret.txt")
      touch("uploads/other.png")

      expect(find(filename: "../secret.txt", path: nil)).to be_nil
    end
  end

  describe "#tempfile_from_data" do
    it "writes the blob to a rewound binary tempfile the caller owns" do
      file = described_class.new(root_paths: []).tempfile_from_data("\x00binary\xFF".b)

      expect(File.binread(file.path)).to eq("\x00binary\xFF".b)
      expect(file.pos).to eq(0)
    ensure
      file&.close!
    end
  end
end
