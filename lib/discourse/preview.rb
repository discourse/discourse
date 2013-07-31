require_relative "preview/example"

module Discourse
  module Oneboxer
    class Preview
      def initialize(link)
        @url = link
        @resource = open(@url)
        @document = Nokogiri::HTML(@resource)
      end

      def to_s
        @document.to_html
      end

      class InvalidURI < StandardError

      end
    end
  end
end
