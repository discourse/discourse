# frozen_string_literal: true

module Migrations::Database::Schema::DSL
  OutputConfig =
    Data.define(
      :schema_file,
      :models_directory,
      :models_namespace,
      :enums_directory,
      :enums_namespace,
    )

  Configuration = Data.define(:output_config)

  class ConfigBuilder
    def initialize
      @output_config = nil
    end

    def output(&block)
      builder = OutputBuilder.new
      builder.instance_eval(&block)
      @output_config = builder.build
    end

    def build
      unless @output_config
        raise Migrations::Database::Schema::ConfigError,
              "Configuration must include an `output` block."
      end
      Configuration.new(output_config: @output_config)
    end
  end

  class OutputBuilder
    def initialize
      @schema_file = nil
      @models_directory = nil
      @models_namespace = nil
      @enums_directory = nil
      @enums_namespace = nil
    end

    def schema_file(value)
      @schema_file = value
    end

    def models_directory(value)
      @models_directory = value
    end

    def models_namespace(value)
      @models_namespace = value
    end

    def enums_directory(value)
      @enums_directory = value
    end

    def enums_namespace(value)
      @enums_namespace = value
    end

    def build
      unless @schema_file
        raise Migrations::Database::Schema::ConfigError,
              "Output configuration must include `schema_file`."
      end
      OutputConfig.new(
        schema_file: @schema_file,
        models_directory: @models_directory,
        models_namespace: @models_namespace,
        enums_directory: @enums_directory,
        enums_namespace: @enums_namespace,
      )
    end
  end
end
