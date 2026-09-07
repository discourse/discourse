# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class DeclareNamespace < Matcher
    attr_reader :namespace

    def initialize(namespace)
      @namespace = namespace.to_s
    end

    def satisfied?
      resource.namespace == namespace
    end

    def description
      "declare the namespace #{namespace.inspect}"
    end

    def failure_message
      "Expected #{resource} to declare the namespace #{namespace.inspect}, " \
        "but it declares #{resource.namespace&.inspect || "none"}."
    end
  end
end
