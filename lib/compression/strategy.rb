# frozen_string_literal: true

module Compression
  class Strategy
    ExtractFailed = Class.new(StandardError)
    DestinationFileExistsError = Class.new(StandardError)

    def can_handle?(file_name)
      file_name.include?(extension)
    end

    def decompress(dest_path, compressed_file_path, max_size)
      sanitized_compressed_file_path = sanitize_path(compressed_file_path)
      sanitized_dest_path = sanitize_path(dest_path)

      get_compressed_file_stream(sanitized_compressed_file_path) do |compressed_file|
        available_size = calculate_available_size(max_size)

        entries_of(compressed_file).each do |entry|
          entry_path = build_entry_path(sanitized_dest_path, entry, sanitized_compressed_file_path)
          next if !is_safe_path_for_extraction?(entry_path, sanitized_dest_path)

          FileUtils.mkdir_p(File.dirname(entry_path))
          if is_file?(entry)
            remaining_size = extract_file(entry, entry_path, available_size)
            available_size = remaining_size
          else
            extract_folder(entry, entry_path)
          end
        end
        decompression_results_path(sanitized_dest_path, sanitized_compressed_file_path)
      end
    end

    private

    def sanitize_path(filename)
      Pathname.new(filename).realpath.to_s
    end

    def calculate_available_size(max_size)
      1024**2 * (max_size / 1.049) # Mb to Mib
    end

    def entries_of(compressed_file)
      compressed_file
    end

    def is_file?(entry)
      entry.file?
    end

    def chunk_size
      @chunk_size ||= 1024**2 * 2 # 2MiB
    end

    def extract_file(entry, entry_path, available_size)
      remaining_size = available_size

      if ::File.exist?(entry_path)
        raise DestinationFileExistsError, "Destination '#{entry_path}' already exists"
      end

      ::File.open(entry_path, "wb") do |os|
        while (buf = entry.read(chunk_size))
          remaining_size -= buf.size
          raise ExtractFailed if remaining_size.negative?
          os << buf
        end
      end

      remaining_size
    end

    def is_safe_path_for_extraction?(path, dest_directory)
      File.expand_path(path).start_with?(dest_directory)
    end
  end
end
