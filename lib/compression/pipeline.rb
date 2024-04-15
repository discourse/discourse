# frozen_string_literal: true

module Compression
  class Pipeline < Strategy
    def initialize(strategies)
      @strategies = strategies
    end

    def extension
      @strategies.reduce("") { |ext, strategy| ext += strategy.extension }
    end

    def compress(path, target_name)
      current_target = target_name
      @strategies.reduce(nil) do |_, strategy|
        compressed_path = strategy.compress(path, current_target)
        current_target = compressed_path.split("/").last
        compressed_path
      end
    end

    def decompress(dest_path, compressed_file_path, max_size)
      @strategies
        .reverse
        .reduce(compressed_file_path) do |to_decompress, strategy|
          next_compressed_file = strategy.decompress(dest_path, to_decompress, max_size)
          FileUtils.rm_rf(to_decompress)
          next_compressed_file
        end
    end
  end
end
