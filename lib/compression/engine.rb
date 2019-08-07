# frozen_string_literal: true

require_dependency 'compression/zip'
require_dependency 'compression/tar_gzip'
require_dependency 'compression/tar'

module Compression
  class Engine
    ExtractFailed = Class.new(StandardError)

    def self.engine_for(filename)
      available_engines = [::Compression::Zip, ::Compression::TarGzip, ::Compression::Tar]
      strategy = available_engines.detect { |e| e.can_handle?(filename) }.new
      new(strategy)
    end

    def initialize(strategy)
      @strategy = strategy
    end

    def decompress(dest_path, compressed_file_path, allow_non_root_folder: false)
      @strategy.decompress(dest_path, compressed_file_path, allow_non_root_folder: false)
    end

    def compress(path, target_name)
      @strategy.compress(path, target_name)
    end
  end
end
