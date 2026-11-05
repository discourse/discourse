# frozen_string_literal: true

module JsonApiKit
  class Request
    class Invalid < StandardError
      def initialize(refusals)
        @refusals = refusals
        super(refusals.map(&:detail).join(" "))
      end

      attr_reader :refusals
    end
  end
end
