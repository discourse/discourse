require_relative "preview/example"
require_relative "preview/amazon"
require_relative "preview/stackexchange"

module Onebox
  class Preview
    def initialize(link)
      @url = link
      @resource = open(@url)
      @document = Nokogiri::HTML(@resource)
    end

    def to_s
      case @url
      when /example\.com/ then Example
      when /amazon\.com/ then Amazon
      when /stackexchange\.com/ then StackExchange
      end.new(@document, @url).to_html
    end

    class InvalidURI < StandardError

    end
  end
end

