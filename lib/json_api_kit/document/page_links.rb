# frozen_string_literal: true

module JsonApiKit
  class Document
    class PageLinks
      def initialize(url, pages)
        @url = url
        @pages = pages
      end

      def to_h
        return {} if pages.empty?
        { prev: link(:before, pages[:before]), next: link(:after, pages[:after]) }
      end

      private

      attr_reader :url, :pages

      def link(end_of_the_page, cursor)
        return unless cursor
        url.at(end_of_the_page => cursor).to_s
      end
    end
  end
end
