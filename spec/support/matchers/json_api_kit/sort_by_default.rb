# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class SortByDefault < Matcher
    attr_reader :ordering

    def initialize(ordering)
      @ordering = ordering.to_h { |name, direction| [name.to_s, direction.to_sym] }
    end

    def satisfied?
      leading_keys == ordering.to_a && runs?
    end

    def description
      "sort by default on #{ordering.map { |name, direction| "#{name} #{direction}" }.join(", ")}"
    end

    def failure_message
      if leading_keys != ordering.to_a
        return "Expected #{resource} to #{description}, but it sorts on #{spell(leading_keys)}."
      end
      "Expected #{resource} to #{description}, but reading it raised #{@error.class}: " \
        "#{@error.message.lines.first.strip}"
    end

    private

    def leading_keys
      @leading_keys ||=
        resource
          .order
          .first
          .keyset
          .keys
          .first(ordering.size)
          .map { [it.name.to_s, it.direction.to_sym] }
    end

    def spell(pairs) = in_words(pairs.map { |name, direction| "#{name} #{direction}" })

    def runs?
      resource.all({}, guardian: Guardian.new).records
      true
    rescue StandardError => error
      @error = error
      false
    end
  end
end
