# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class DeclareModel < Matcher
    attr_reader :model

    def initialize(model)
      @model = model
    end

    def satisfied?
      resource_model == model && model.table_exists?
    end

    def description
      "declare the model #{model}"
    end

    def failure_message
      return missing_model_message unless resource_model
      if resource_model != model
        return(
          "Expected #{resource} to declare the model #{model}, but it declares #{resource_model}."
        )
      end
      "Expected #{resource} to declare the model #{model}, " \
        "but the table #{model.table_name} does not exist."
    end

    private

    def resource_model
      @resource_model ||= resource.model
    rescue JsonApiKit::Resource::MissingDeclaration => error
      @missing = error.message
      nil
    end

    def missing_model_message
      "Expected #{resource} to declare the model #{model}, but it has no model: #{@missing}"
    end
  end
end
