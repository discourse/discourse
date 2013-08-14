module Onebox
  class Preview
    def initialize(link)
      @url = link
      @resource = open(@url)
      @document = Nokogiri::HTML(@resource)
      @engine = Matcher.new(@url).oneboxed
    end

    def to_s
      engine.to_html
    end

    private

    def engine
      @engine.new(@document, @url)
    end

    class InvalidURI < StandardError

    end
  end
end

