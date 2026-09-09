# frozen_string_literal: true

module JsonApiKit
  module Page
    class PerOwner
      def initialize(owner_key)
        @owner_key = owner_key
      end

      def paginate(scope, order:, limits:, anchors: nil)
        Pagination::PagePerOwner.new(scope, order:, size: limits.size, owner_key:)
      end

      private

      attr_reader :owner_key
    end
  end
end
