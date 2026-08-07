# frozen_string_literal: true

module JsonApiKit
  module Declarations
    # How large a page of a resource may be: the size it is read at when a request asks for none,
    # and the most it will read when one does. A page a client can make arbitrarily large is a
    # table scan it can ask for, so the maximum is the resource's to give rather than the
    # caller's to take.
    #
    # Sizes arrive as numbers: whether `page[size]=x` is a number at all is the spec's business,
    # settled before a resource is asked anything.
    class PageLimits
      TooLarge = Class.new(StandardError)

      DEFAULT = 25
      MAX = 100

      def initialize(default: DEFAULT, max: MAX)
        @default = default
        @max = max
      end

      def size(asked = nil)
        return default unless asked
        raise TooLarge, too_large(asked) if asked > max
        asked
      end

      private

      attr_reader :default, :max

      def too_large(asked) = "a page of #{asked} rows is more than the #{max} this resource reads"
    end
  end
end
