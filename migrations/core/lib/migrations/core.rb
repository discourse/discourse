# frozen_string_literal: true

require "zeitwerk"

module Migrations
  module Core
    class << self
      def loader
        @loader ||=
          Zeitwerk::Loader.new.tap do |loader|
            core_dir = File.expand_path("core", __dir__)
            loader.tag = "migrations-core"
            loader.inflector.inflect("cli" => "CLI")
            loader.push_dir(core_dir, namespace: Migrations::Core)
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
