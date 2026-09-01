# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class FilterOn < Matcher
    PROBE = "a value no row holds"

    attr_reader :names

    def initialize(names)
      @names = names.map(&:to_s)
    end

    def satisfied?
      return false if undeclared.any?
      @failure = filter_failure
      @failure.nil?
    end

    def description
      "filter on #{names.join(", ")}"
    end

    def failure_message
      if undeclared.any?
        return(
          "Expected #{resource} to filter on #{undeclared.join(", ")}, " \
            "but it filters on #{in_words(resource.filter_names)}."
        )
      end
      name, error = @failure
      "Expected #{resource} to filter on #{name}, but filtering by it raised #{error.class}: " \
        "#{error.message.lines.first.strip}"
    end

    private

    def undeclared = @undeclared ||= names - resource.filter_names

    def filter_failure
      names.each do |name|
        resource.all({ filter: { name => PROBE } }, guardian: Guardian.new).records
      rescue StandardError => error
        return name, error
      end
      nil
    end
  end
end
