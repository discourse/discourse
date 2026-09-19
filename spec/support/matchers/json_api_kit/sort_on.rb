# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class SortOn < Matcher
    DIRECTIONS = { asc: "ascending", desc: "descending" }.freeze

    attr_reader :names

    def initialize(names)
      @names = names.map(&:to_s)
    end

    def satisfied?
      return false if undeclared.any?
      @failure = sort_failure
      @failure.nil?
    end

    def description
      "sort on #{names.join(", ")}"
    end

    def failure_message
      return undeclared_message if undeclared.any?
      name, direction, error = @failure
      "Expected #{resource} to sort on #{name}, but reading it #{DIRECTIONS.fetch(direction)} " \
        "raised " \
        "#{error.class}: #{error.message.lines.first.strip}"
    end

    private

    def undeclared = @undeclared ||= names - resource.sort_names

    def undeclared_message
      "Expected #{resource} to sort on #{undeclared.join(", ")}, " \
        "but it sorts on #{in_words(resource.sort_names)}."
    end

    def sort_failure
      names
        .product(DIRECTIONS.keys)
        .each do |name, direction|
          resource.all({ sort: { name => direction } }, guardian: Guardian.new).records
        rescue StandardError => error
          return name, direction, error
        end
      nil
    end
  end
end
