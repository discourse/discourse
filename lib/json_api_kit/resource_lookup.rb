# frozen_string_literal: true

module JsonApiKit
  class ResourceLookup
    MissingResource = Class.new(StandardError)
    UnsupportedResource = Class.new(StandardError)

    def self.resource(...) = new(...).resource

    private_class_method :new

    def initialize(declaration, within:)
      @declaration = declaration
      @within = within
    end

    def resource
      return resolved_class if resolved_class.ancestors.include?(Resource)
      raise UnsupportedResource, "#{within}: #{resolved_class} is not a JSON:API resource"
    end

    private

    attr_reader :declaration, :within

    def resolved_class
      @resolved_class ||=
        if declaration.is_a?(Class)
          declaration
        else
          candidates.filter_map(&:safe_constantize).first or raise MissingResource, no_resource
        end
    end

    def candidates
      @candidates ||= within.module_parents.map { it == Object ? basename : "#{it}::#{basename}" }
    end

    def basename = "#{declaration.to_s.singularize.camelize}Resource"

    def no_resource
      "#{within}: no resource is named #{declaration}, tried #{candidates.join(", ")}"
    end
  end
end
