# frozen_string_literal: true

module JsonApiKit
  # What a type exposes, declared in one place: the model behind it, the name it goes out
  # under, and — as they arrive — its attributes, relationships, filters and sorts. A resource
  # records its declarations and answers questions about them; reading rows and rendering
  # documents belong to the objects that consult it.
  #
  # The model and the type are read off the resource's own name, the way Rails reads an
  # association's class off its name, and are declared only where that cannot work. Nothing is
  # inferred until something asks, so a resource never depends on what is loaded when it is
  # defined.
  class Resource
    MissingDeclaration = Class.new(StandardError)

    NAMING = /\A(?<path>(?:\w+::)*(?<subject>\w+))Resource\z/
    private_constant :NAMING

    class_attribute :declared_model,
                    :declared_type,
                    instance_accessor: false,
                    instance_predicate: false
    private_class_method :declared_model, :declared_model=, :declared_type, :declared_type=

    class << self
      # Declares the model when given one and answers with it when not. A declaration can name
      # the model — `model :topic`, `model "discourse_data_explorer/query"` — instead of
      # referencing the class, which leaves the constant unloaded until something asks.
      def model(declaration = nil)
        return resolved_model unless declaration
        self.declared_model = declaration
      end

      # The type as it goes on the wire, and a string wherever it is compared: a `fields[…]`
      # key, a document's `type` and a relationship's target all arrive as one.
      def type(declaration = nil)
        return declared_type || inferred_type unless declaration
        self.declared_type = declaration.to_s
      end

      private

      # A declared name and the resource's own are the same problem, so both resolve here; a
      # class that was handed over directly travels as itself.
      def resolved_model = @resolved_model ||= model_for(declared_model || naming[:path])

      def model_for(model)
        return model if model.is_a?(Class)
        model.to_s.camelize.safe_constantize or raise MissingDeclaration, no_model(model)
      end

      def inferred_type = @inferred_type ||= naming[:subject].underscore.pluralize

      # A resource is named after what it exposes, plus the suffix that marks the class as a
      # resource: its model's name is that name in full, its type's is the last segment of it.
      def naming
        name&.match(NAMING) or raise MissingDeclaration, nothing_to_infer_from
      end

      def no_model(model)
        "#{self}: no model is named #{model.to_s.camelize}, declare it with `model SomeModel`"
      end

      def nothing_to_infer_from
        "#{inspect} is not named after what it exposes: declare `model SomeModel` and `type :things`"
      end
    end
  end
end
