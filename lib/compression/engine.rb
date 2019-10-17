# frozen_string_literal: true

module Compression
  class Engine
    UnsupportedFileExtension = Class.new(StandardError)

    def self.default_strategies
      [
        Compression::Zip.new,
        Compression::Pipeline.new([Compression::Tar.new, Compression::Gzip.new]),
        Compression::Gzip.new,
        Compression::Tar.new
      ]
    end

    def self.engine_for(filename, strategies: default_strategies)
      strategy = strategies.detect(-> { raise UnsupportedFileExtension }) { |e| e.can_handle?(filename) }
      new(strategy)
    end

    def initialize(strategy)
      @strategy = strategy
    end

    delegate :extension, :decompress, :compress, :strip_directory, to: :@strategy
  end
end
