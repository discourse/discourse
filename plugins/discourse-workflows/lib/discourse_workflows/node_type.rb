# frozen_string_literal: true

module DiscourseWorkflows
  class NodeType
    extend NodeTypeDescriptor

    TYPE_EXEMPLARS = {
      string: "",
      integer: 0,
      number: 0,
      boolean: false,
      array: [],
      object: {
      },
    }.freeze

    def self.inherited(subclass)
      super
      DiscourseWorkflows::NodeType.registered_nodes << subclass
    end

    def self.registered_nodes
      @registered_nodes ||= []
    end

    def self.waiting_identifiers
      registered_nodes.select(&:waits_for_resume?).map(&:identifier)
    end

    def self.waits_for_resume?
      false
    end

    def self.identifier
      raise NotImplementedError
    end

    def self.icon
      nil
    end

    def self.color
      nil
    end

    def self.palette_visible?
      true
    end

    def self.available?
      true
    end

    def self.unavailable_reason_key
      nil
    end

    def self.inputs
      [:main]
    end

    def self.outputs
      [:main]
    end

    def self.property_schema
      {}
    end

    def self.event_name
      nil
    end

    def self.manually_triggerable?
      false
    end

    def self.provides_current_user?
      false
    end

    def self.output_schema
      {}
    end

    def self.output_exemplar
      exemplar_from_schema(output_schema)
    end

    def self.exemplar_from_schema(schema)
      schema.each_with_object({}) do |(key, value), hash|
        hash[key.to_s] = if value.is_a?(Hash)
          exemplar_from_schema(value)
        else
          TYPE_EXEMPLARS.fetch(value, "")
        end
      end
    end

    def self.schema_extensions
      @schema_extensions || []
    end

    def self.extend_schema(name, fields:, resolver:)
      @schema_extensions ||= []
      @schema_extensions << { name: name, fields: fields, resolver: resolver }
    end

    def initialize(configuration: {})
      @configuration = configuration
    end

    def execute(exec_ctx)
      raise NotImplementedError
    end

    def valid?
      true
    end

    def output
      raise NotImplementedError
    end

    private

    def wrap(data)
      Item.wrap(data)
    end

    def skip_workflows?(opts)
      opts.is_a?(Hash) && opts.with_indifferent_access[:skip_workflows]
    end
  end
end
