# frozen_string_literal: true

module JsonApiKit
  class DefaultSorts
    def initialize(changes)
      @changes = changes
      @orderings = {}
    end

    def for(resource) = orderings[resource] ||= ordering_for(resource)

    private

    attr_reader :changes, :orderings

    def ordering_for(resource)
      defaults
        .fetch(resource.type) { return resource.default_ordering }
        .then { resource.default_ordering(it.ordering) }
    end

    def defaults
      @defaults ||= changes.reduce({}) { |defaults, change| advance(defaults, through: change) }
    end

    def advance(defaults, through:)
      translated_defaults(defaults, through:).merge(
        through.current_default_sorts.index_by(&:type),
      ) { |_type, earlier_default, _later_default| earlier_default }
    end

    def translated_defaults(defaults, through:)
      defaults
        .values
        .map { |default| default.convert_names { through.current_names(it).sole } }
        .index_by(&:type)
    end
  end
end
