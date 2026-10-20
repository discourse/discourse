# frozen_string_literal: true

module JsonApiKit
  class Query
    class Collection < Query
      def pages = { before: previous, after: self.next }

      def next = page.next&.to_s

      def previous = page.previous&.to_s
    end
  end
end
