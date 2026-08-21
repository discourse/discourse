# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Anchors
      delegate :fetch, to: :anchors

      def initialize(anchors, guardian:)
        @anchors = anchors.index_by(&:name)
        @guardian = guardian
      end

      def locate(anchoring, scope:, order:)
        fetch(anchoring.name).locate(scope, value: anchoring.value, order:, guardian:)
      end

      private

      attr_reader :anchors, :guardian
    end
  end
end
