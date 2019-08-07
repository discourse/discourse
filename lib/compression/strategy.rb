# frozen_string_literal: true

module Compression
  class Strategy
    def decompress(dest_path, compressed_file_path, allow_non_root_folder: false)
      get_compressed_file_stream(compressed_file_path) do |compressed_file|
        available_size = calculate_available_size(compressed_file_path, compressed_file)

        compressed_file.each do |entry|
          entry_path = build_entry_path(
            compressed_file, dest_path,
            compressed_file_path, entry,
            allow_non_root_folder
          )

          if entry.file?
            remaining_size = extract_file(entry, entry_path, available_size)
            available_size = remaining_size
          else
            extract_folder(entry, entry_path)
          end
        end
      end
    end

    private

    def chunk_size
      @chunk_size ||= ::Zip::Decompressor::CHUNK_SIZE
    end
  end
end
