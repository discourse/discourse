# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class Expose < Matcher
    attr_reader :names

    def initialize(names)
      @names = names.map(&:to_s)
    end

    def readable_by(guardian, record: nil)
      @reader = guardian
      @reader_record = record
      self
    end

    def hidden_from(guardian, record: nil)
      @stranger = guardian
      @stranger_record = record
      self
    end

    def satisfied?
      undeclared.empty? && hidden.empty? && shown.empty? && broken_attribute.nil?
    end

    def description
      ["expose #{names.join(", ")}", *readable_clause, *hidden_clause].join(", ")
    end

    def failure_message
      return undeclared_message if undeclared.any?
      return broken_attribute_message if broken_attribute
      return hidden_message if hidden.any?
      shown_message
    end

    private

    attr_reader :reader, :stranger, :broken_attribute

    def undeclared = @undeclared ||= names - resource.attribute_names

    def hidden = @hidden ||= reader ? names - names_for_reader : []

    def shown = @shown ||= stranger ? names & names_for_stranger : []

    def names_for_reader = readable(reader, @reader_record)

    def names_for_stranger = readable(stranger, @stranger_record)

    def readable(guardian, record)
      attributes = resource.fields(guardian:).attributes
      return attributes.names unless record
      attributes.values_for(record).keys
    rescue NoMethodError => error
      @broken_attribute = error.name
      []
    end

    def broken_attribute_message
      "Expected #{resource} to expose #{names.join(", ")}, but the attribute " \
        "#{broken_attribute} cannot be read from a #{resource.model}."
    end

    def readable_clause = reader ? ["readable by #{name_of(reader)}"] : []

    def hidden_clause = stranger ? ["hidden from #{name_of(stranger)}"] : []

    def name_of(guardian) = guardian.user&.username || "anonymous"

    def undeclared_message
      "Expected #{resource} to expose #{undeclared.join(", ")}, " \
        "but it exposes #{in_words(resource.attribute_names)}."
    end

    def hidden_message
      "Expected #{resource} to expose #{hidden.join(", ")} to #{name_of(reader)}, but it is hidden."
    end

    def shown_message
      "Expected #{resource} to hide #{shown.join(", ")} from #{name_of(stranger)}, " \
        "but it is readable."
    end
  end
end
