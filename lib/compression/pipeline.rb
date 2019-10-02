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

    def decompress(dest_path, compressed_file_path, allow_non_root_folder: false)
      to_decompress = compressed_file_path
      @strategies.reverse.each do |strategy|
        last_extension = strategy.extension
        strategy.decompress(dest_path, to_decompress, allow_non_root_folder: allow_non_root_folder)
        to_decompress = compressed_file_path.gsub(last_extension, '')
      end
    end
  end
end
