# frozen_string_literal: true

RSpec.describe BackupRestore::ArchiveWriter do
  it "streams files, long names and hardlinks into an archive readable by tar" do
    Dir.mktmpdir do |directory|
      source = File.join(directory, "source")
      File.binwrite(source, "archive contents\0" * 1000)
      archive = File.join(directory, "backup.tar")
      # Exercise PAX path and linkpath headers, including byte lengths for UTF-8.
      path = "uploads/#{"a" * 150}/#{"é" * 70}.txt"
      link = "uploads/#{"b" * 150}/duplicate.txt"

      described_class.open(archive) do |writer|
        writer.add_directory("db")
        writer.add_file(source, path)
        writer.add_hardlink(link, path)
      end

      extracted = File.join(directory, "extracted")
      FileUtils.mkdir_p(extracted)
      Discourse::Utils.execute_command("tar", "-xf", archive, "-C", extracted)

      expect(File.binread(File.join(extracted, path))).to eq(File.binread(source))
      expect(File.stat(File.join(extracted, path)).ino).to eq(
        File.stat(File.join(extracted, link)).ino,
      )
      expect(File.directory?(File.join(extracted, "db"))).to eq(true)
    end
  end

  it "preserves local hardlinks and starts a new copy when the link limit is reached" do
    Dir.mktmpdir do |directory|
      paths = 5.times.map { |i| File.join(directory, "file#{i}") }
      File.write(paths.first, "shared contents")
      paths.drop(1).each { |path| File.link(paths.first, path) }
      archive = File.join(directory, "backup.tar")
      stub_const(described_class, "MAX_LINKS", 2) do
        described_class.open(archive) do |writer|
          paths.each { |path| writer.add_file(path, File.basename(path)) }
        end
      end

      extracted = File.join(directory, "extracted")
      FileUtils.mkdir_p(extracted)
      Discourse::Utils.execute_command("tar", "-xf", archive, "-C", extracted)
      files = paths.map { |path| File.join(extracted, File.basename(path)) }
      expect(files.map { |path| File.read(path) }).to eq(["shared contents"] * 5)
      inodes = files.map { |path| File.stat(path).ino }
      expect(inodes[0]).to eq(inodes[1])
      expect(inodes[2]).to eq(inodes[3])
      expect(inodes.values_at(0, 2, 4).uniq.size).to eq(3)
    end
  end

  it "uses an extended size header for files too large for a traditional tar header" do
    io = StringIO.new
    described_class.new(io).send(:write_header, "db/large.dat.gz", size: 8 * 1024**3)
    io.rewind

    pax = Gem::Package::TarHeader.from(io)
    expect(pax.typeflag).to eq("x")
    record = io.read(pax.size)
    expect(record).to include(" size=8589934592\n")
    expect(record.split(" ").first.to_i).to eq(record.bytesize)
  end

  it "preserves large numeric owners in PAX fields understood by tar" do
    Dir.mktmpdir do |directory|
      archive = File.join(directory, "backup.tar")
      File.open(archive, "wb") do |io|
        described_class.write(io) do |writer|
          writer.send(:write_header, "large-owner", uid: 1_000_680_000, gid: 2_097_152)
        end
      end
      listing = Discourse::Utils.execute_command("tar", "--numeric-owner", "-tvf", archive)
      expect(listing).to include("1000680000/2097152")
    end
  end

  it "preserves file ownership and permissions in the archive" do
    Dir.mktmpdir do |directory|
      source = File.join(directory, "source")
      File.write(source, "contents")
      File.chmod(0o640, source)
      io = StringIO.new
      described_class.new(io).add_file(source, "source")
      io.rewind

      header = Gem::Package::TarHeader.from(io)
      expect(header.mode).to eq(0o640)
      expect(header.uid).to eq(File.stat(source).uid)
      expect(header.gid).to eq(File.stat(source).gid)
      expect(header.uname).to eq("")
      expect(header.gname).to eq("")
    end
  end

  it "fails if an input file is truncated while being archived" do
    Dir.mktmpdir do |directory|
      source = File.join(directory, "source")
      File.write(source, "original content")
      IO.expects(:copy_stream).returns(1)

      expect do
        described_class.open(File.join(directory, "backup.tar")) do |writer|
          writer.add_file(source, "source")
        end
      end.to raise_error(/File shrank while archiving/)
    end
  end
end
