# frozen_string_literal: true

module JsonApiKit
  class DefaultSort
    attr_reader :type, :ordering

    def initialize(type, ordering)
      @type = type.to_s
      @ordering = ordering.to_h.transform_keys(&:to_s).freeze
      @ordering.each_value { Pagination::Direction.for(it) }
    end

    def convert_names(&conversion)
      self.class.new(
        conversion.call(Name::Type.new(value: type)).value,
        converted_ordering(&conversion),
      )
    end

    private

    def converted_ordering
      ordering
        .group_by { |name, _direction| yield(Name::Sort.new(value: name, type:)) }
        .to_h { |name, entries| [name.value, direction_for(name, entries)] }
    end

    def direction_for(name, entries)
      entries.map(&:last).uniq.sole
    rescue Enumerable::SoleItemExpectedError
      raise ArgumentError, "The default sort for #{type} has conflicting directions for #{name}."
    end
  end
end
