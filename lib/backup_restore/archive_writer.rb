# frozen_string_literal: true

require "rubygems/package"

module BackupRestore
  # Streams tar entries directly to the final archive.
  class ArchiveWriter
    def self.open(path)
      File.open(path, "wb") { |file| write(file) { |writer| yield writer } }
    end

    def self.write(io)
      yield new(io)
      io.write("\0" * 1024)
    end

    def initialize(io)
      @io = io
    end

    def add_file(source, name, mode: nil)
      File.open(source, "rb") do |file|
        stat = file.stat
        write_header(
          name,
          size: stat.size,
          mode: mode || (stat.mode & 0o777),
          mtime: stat.mtime.to_i,
          uid: stat.uid,
          gid: stat.gid,
        )
        copied = IO.copy_stream(file, @io, stat.size)
        raise "File shrank while archiving: #{source}" if copied != stat.size
        pad(stat.size)
      end
    end

    def add_directory(name, source: nil)
      stat = File.stat(source) if source
      write_header(
        name,
        typeflag: "5",
        mode: stat ? stat.mode & 0o777 : 0o755,
        mtime: stat ? stat.mtime.to_i : Time.now.to_i,
        uid: stat ? stat.uid : Process.uid,
        gid: stat ? stat.gid : Process.gid,
      )
    end

    def add_hardlink(name, target)
      write_header(name, typeflag: "1", linkname: target)
    end

    private

    def write_header(
      name,
      size: 0,
      typeflag: "0",
      linkname: "",
      mode: 0o644,
      mtime: Time.now.to_i,
      uid: Process.uid,
      gid: Process.gid
    )
      # PAX headers avoid truncating long paths, hardlink targets, or files >= 8 GiB.
      attributes = {}
      attributes["path"] = name if name.bytesize > 100
      attributes["linkpath"] = linkname if linkname.bytesize > 100
      attributes["size"] = size.to_s if size >= 8**11

      if attributes.present?
        data = attributes.map { |key, value| pax_record(key, value) }.join
        @io.write(
          Gem::Package::TarHeader.new(
            name: "PaxHeaders/entry",
            mode: 0o644,
            size: data.bytesize,
            typeflag: "x",
            mtime: mtime,
            prefix: "",
          ).to_s,
        )
        @io.write(data)
        pad(data.bytesize)
      end

      @io.write(
        Gem::Package::TarHeader.new(
          name: attributes.key?("path") ? "entry" : name,
          linkname: attributes.key?("linkpath") ? "" : linkname,
          size: attributes.key?("size") ? 0 : size,
          typeflag: typeflag,
          mode: mode,
          mtime: mtime,
          prefix: "",
          uid: uid,
          gid: gid,
          uname: "",
          gname: "",
        ).to_s,
      )
    end

    def pax_record(key, value)
      record = " #{key}=#{value}\n"
      length = record.bytesize + 1
      loop do
        next_length = record.bytesize + length.to_s.bytesize
        return "#{length}#{record}" if next_length == length
        length = next_length
      end
    end

    def pad(size)
      @io.write("\0" * ((-size) % 512))
    end
  end
end
