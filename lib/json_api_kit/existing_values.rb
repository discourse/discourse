# frozen_string_literal: true

module JsonApiKit
  class ExistingValues
    ConversionFailure = Class.new(StandardError)

    module None
      class << self
        def after(_change) = self

        def fetch(_name) = yield
      end
    end

    def self.for(changes, current:)
      new(
        changes
          .reverse_each
          .each_with_object({}) do |change, boundaries|
            boundaries[change] = current
            current = Previous.new(change, current:)
          end,
      )
    end

    def initialize(boundaries)
      @boundaries = boundaries
    end

    def after(change) = boundaries.fetch(change)

    private

    attr_reader :boundaries
  end
end
