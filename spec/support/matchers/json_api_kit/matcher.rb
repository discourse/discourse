# frozen_string_literal: true

module JsonApiKitMatchers
  class Matcher
    attr_reader :resource

    def matches?(resource)
      @resource = resource
      satisfied?
    end

    def failure_message_when_negated
      "Expected #{resource} not to #{description}."
    end

    private

    def in_words(names)
      names.join(", ").presence || "none"
    end
  end
end
