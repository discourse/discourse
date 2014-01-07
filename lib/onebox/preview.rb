module Onebox
  class Preview
    attr_reader :cache

    def initialize(link, parameters = Onebox.options)
      @url = link
      @options = parameters
      @cache = options.cache
      @engine_class = Matcher.new(@url).oneboxed
    end

    def to_s
      return "" unless engine
      engine.to_html
    rescue Net::HTTPServerException, OpenURI::HTTPError, Timeout::Error, Net::HTTPError
      ""
    end

    def placeholder_html
      return "" unless engine
      engine.placeholder_html
    rescue Net::HTTPServerException, OpenURI::HTTPError, Timeout::Error, Net::HTTPError
      ""
    end

    def options
      OpenStruct.new(@options)
    end

    private

    def engine
      return nil unless @engine_class
      @engine ||= @engine_class.new(@url, cache)
    end

    class InvalidURI < StandardError
    end
  end
end
