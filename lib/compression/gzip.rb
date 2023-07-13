# frozen_string_literal: true

module Compression
  class Gzip < Strategy
    def extension
      ".gz"
    end

    def compress(path, target_name)
      gzip_target = sanitize_path("#{path}/#{target_name}")
      Discourse::Utils.execute_command(
        "gzip",
        "-5",
        gzip_target,
        failure_message: "Failed to gzip file.",
      )

      "#{gzip_target}.gz"
    end

    private

    def entries_of(compressed_file)
      [compressed_file]
    end

    def is_file?(_)
      true
    end

    def extract_folder(_entry, _entry_path)
    end

    def get_compressed_file_stream(compressed_file_path)
      gzip = Zlib::GzipReader.open(compressed_file_path)
      yield(gzip)
    end

    def build_entry_path(dest_path, _, compressed_file_path)
      basename = File.basename(compressed_file_path)
      basename.gsub!(/#{Regexp.escape(extension)}\z/, "")
      File.join(dest_path, basename)
    end

    def decompression_results_path(dest_path, compressed_file_path)
      build_entry_path(dest_path, nil, compressed_file_path)
    end

    def extract_file(entry, entry_path, available_size)
      remaining_size = available_size

      if ::File.exist?(entry_path)
        raise ::Zip::DestinationFileExistsError, "Destination '#{entry_path}' already exists"
      end # Change this later.

      ::File.open(entry_path, "wb") do |os|
        buf = "".dup
        while (buf = entry.read(chunk_size))
          remaining_size -= chunk_size
          raise ExtractFailed if remaining_size.negative?
          os << buf
        end
      end

      remaining_size
    end
  end
end
