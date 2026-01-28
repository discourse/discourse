# frozen_string_literal: true

require "zeitwerk"
require "migrations/core"

module Migrations
  module Converters
    class << self
      def loader
        @loader ||=
          Zeitwerk::Loader.new.tap do |loader|
            converters_dir = File.expand_path("converters", __dir__)
            loader.tag = "migrations-converters"
            loader.push_dir(converters_dir, namespace: Migrations::Converters)
            loader.setup
          end
      end

      def root
        @root ||= File.expand_path("../..", __dir__)
      end
    end

    loader
  end
end
