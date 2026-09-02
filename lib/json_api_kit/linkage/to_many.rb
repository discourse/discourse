# frozen_string_literal: true

module JsonApiKit
  class Linkage
    class ToMany < Linkage
      def initialize(page, previous_page: nil)
        super(page.records)
        @next_page = page.cursor
        @previous_page = previous_page
      end

      def collapse(&) = records.map(&)

      def pages = { before: previous, after: self.next }

      def next = next_page&.to_s

      def previous = previous_page&.to_s

      private

      attr_reader :next_page, :previous_page
    end
  end
end
