# frozen_string_literal: true

module Migrations::Database::Schema::Validation
  class OutputConfigValidator < BaseValidator
    def initialize(config, errors)
      super(config, errors, nil)
      @output_config = config[:output]
    end

    def validate
      validate_schema_file_directory
      validate_models_directory
      validate_models_namespace
    end

    private

    def validate_schema_file_directory
      schema_file_path = File.dirname(@output_config[:schema_file])
      schema_file_path = File.expand_path(schema_file_path, ::Migrations.root_path)

      if !Dir.exist?(schema_file_path)
        @errors << I18n.t("schema.validator.output.schema_file_directory_not_found")
      end
    end

    def validate_models_directory
      models_directory = File.expand_path(@output_config[:models_directory], ::Migrations.root_path)

      if !Dir.exist?(models_directory)
        @errors << I18n.t("schema.validator.output.models_directory_not_found")
      end
    end

    def validate_models_namespace
      existing_namespace =
        begin
          Object.const_get(@output_config[:models_namespace]).is_a?(Module)
        rescue NameError
          false
        end

      @errors << I18n.t("schema.validator.output.models_namespace_undefined") if !existing_namespace
    end
  end
end
