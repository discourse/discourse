# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class EmptyPage
      def rows = []

      def next = nil

      def previous = nil
    end
  end
end
