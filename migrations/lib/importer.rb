# frozen_string_literal: true

module Migrations
  module Importer
    def self.execute(options)
      config_path = File.join(::Migrations.root_path, "config", "importer.yml")
      config = YAML.load_file(config_path, symbolize_names: true)

      executor = Executor.new(config, options)
      executor.start
    end
  end
end
