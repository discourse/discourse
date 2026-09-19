# frozen_string_literal: true

module JsonApiKit
  class DefaultSorts
    def initialize(changes)
      @changes = changes
      @orderings = {}
    end

    def for(resource) = orderings[resource] ||= History.new(resource:, changes:).ordering

    private

    attr_reader :changes, :orderings
  end
end
