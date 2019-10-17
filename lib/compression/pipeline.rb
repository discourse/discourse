# frozen_string_literal: true

module Compression
  class Pipeline < Strategy
    def initialize(strategies)
      @strategies = strategies
    end

    def extension
      @strategies.reduce('') { |ext, strategy| ext += strategy.extension }
    end

    def compress(path, target_name)
      current_target = target_name
      @strategies.reduce('') do |compressed_path, strategy|
        compressed_path = strategy.compress(path, current_target)
        current_target = compressed_path.split('/').last

        compressed_path
      end
    end

    def decompress(dest_path, compressed_file_path, max_size, allow_non_root_folder: false)
      @strategies.reverse.reduce(compressed_file_path) do |to_decompress, strategy|
        last_extension = strategy.extension
        strategy.decompress(dest_path, to_decompress, max_size, allow_non_root_folder: allow_non_root_folder)
        to_decompress.gsub(last_extension, '')
      end
    end
  end
end
