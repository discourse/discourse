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
