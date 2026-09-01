# frozen_string_literal: true

module JsonApiKit
  module Page
    class Requested
      class << self
        def for(size: nil, after: nil, before: nil, anchoring: nil, **window)
          return Around.new(anchoring, size:, **window) if anchoring
          return After.new(after, size:) if after
          return Before.new(before, size:) if before
          First.new(size:)
        end
      end

      def initialize(size: nil)
        @size = size
      end

      private

      attr_reader :size
    end
  end
end
