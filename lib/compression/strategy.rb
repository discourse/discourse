# frozen_string_literal: true

module Compression
  class Strategy
    ExtractFailed = Class.new(StandardError)
    DestinationFileExistsError = Class.new(StandardError)

    def can_handle?(file_name)
      file_name.include?(extension)
    end

    def decompress(dest_path, compressed_file_path, allow_non_root_folder: false)
      get_compressed_file_stream(compressed_file_path) do |compressed_file|
        available_size = calculate_available_size(compressed_file_path, compressed_file)

        entries_of(compressed_file).each do |entry|
          entry_path = build_entry_path(
            compressed_file, dest_path,
            compressed_file_path, entry,
            allow_non_root_folder
          )

          if is_file?(entry)
            remaining_size = extract_file(entry, entry_path, available_size)
            available_size = remaining_size
          else
            extract_folder(entry, entry_path)
          end
        end
      end
    end

    private

    def calculate_available_size(compressed_file_path, compressed_file)
      1024**2 * (SiteSetting.decompressed_file_max_size_mb / 1.049) # Mb to Mib
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

      ::File.open(entry_path, 'wb') do |os|
        buf = ''.dup
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
