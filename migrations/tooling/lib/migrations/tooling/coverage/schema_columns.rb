# frozen_string_literal: true

module Migrations
  module Tooling
    module Coverage
      # Introspects the generated IntermediateDB models to discover the column
      # contract each one expects.
      #
      # A model's columns are read from the keyword signature of its generated
      # `.create` method: `:keyreq` parameters are required, `:key` parameters are
      # optional. Required columns are already enforced by Ruby (omitting one
      # raises), so the value this check adds is over the optional ones — but both
      # are part of the contract and returned here.
      #
      # Only models produced by `disco schema generate` are part of the contract:
      # manual (hand-written) models such as `Upload` and `LogEntry` are excluded,
      # because they intentionally expose a bespoke API rather than the generated
      # column-per-keyword `.create`.
      module SchemaColumns
        # Substring of the header `disco schema generate` writes into every
        # generated model file. Manual models lack it, which is how we tell the
        # two apart from migrations-core alone. Shared with the generator and the
        # artifacts checker so the three agree on what marks a generated file.
        GENERATED_MARKER = Schema::DSL::GeneratedFiles::MARKER
        private_constant :GENERATED_MARKER

        Model =
          Data.define(:name, :required, :optional) do
            # All columns the generated `.create` accepts, required first.
            def columns
              required + optional
            end

            # The IntermediateDB table the model writes to, e.g.
            # `UserCustomField` => `user_custom_fields`. Display only.
            def table_name
              name.underscore.pluralize
            end
          end

        # @return [Hash{String => Model}] generated models keyed by their constant
        #   name (e.g. "User"), in sorted order.
        def self.call
          namespace = Migrations::Database::IntermediateDB

          namespace
            .constants(false)
            .sort
            .each_with_object({}) do |const_name, models|
              model = build_model(namespace, const_name)
              models[model.name] = model if model
            end
        end

        def self.build_model(namespace, const_name)
          value = namespace.const_get(const_name)
          return unless value.is_a?(Module)
          return unless value.respond_to?(:create)
          return unless generated?(value)

          required = []
          optional = []

          value
            .method(:create)
            .parameters
            .each do |type, name|
              case type
              when :keyreq
                required << name
              when :key
                optional << name
              end
            end

          Model.new(name: const_name.to_s, required:, optional:)
        end
        private_class_method :build_model

        def self.generated?(model)
          path, = model.method(:create).source_location
          return false unless path

          File.read(path).include?(GENERATED_MARKER)
        end
        private_class_method :generated?
      end
    end
  end
end
