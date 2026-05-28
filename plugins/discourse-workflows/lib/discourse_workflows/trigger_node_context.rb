# frozen_string_literal: true

module DiscourseWorkflows
  class TriggerNodeContext
    MISSING = Object.new.freeze

    def self.from_published_trigger(published_trigger)
      new(published_trigger.trigger_node)
    end

    def initialize(trigger_node)
      @trigger_node = trigger_node
    end

    def get_node_parameter(parameter_name, default = nil, _options = {})
      value = parameter_value(parameter_name)
      value.equal?(MISSING) ? default : value
    end

    private

    def parameters
      @parameters ||= DiscourseWorkflows::NodeData.parameters(@trigger_node)
    end

    def parameter_value(parameter_name)
      segments = parameter_name.to_s.split(".").reject(&:blank?)
      return MISSING if segments.empty?

      segments.reduce(parameters) do |current, segment|
        case current
        when Hash
          current.fetch(segment) { current.fetch(segment.to_sym, MISSING) }
        when Array
          return MISSING unless segment.match?(/\A\d+\z/)

          current.fetch(segment.to_i) { return MISSING }
        else
          return MISSING
        end
      end
    end
  end
end
