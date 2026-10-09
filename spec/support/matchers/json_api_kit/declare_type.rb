# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class DeclareType < Matcher
    attr_reader :type

    def initialize(type)
      @type = type.to_s
    end

    def satisfied?
      resource.type == type
    end

    def description
      "declare the type #{type.inspect}"
    end

    def failure_message
      "Expected #{resource} to declare the type #{type.inspect}, " \
        "but it declares #{resource.type.inspect}."
    end
  end
end
