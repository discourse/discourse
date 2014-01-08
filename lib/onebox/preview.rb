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
      engine.to_html || ""
    rescue *Onebox::Preview.web_exceptions
      ""
    end

    def placeholder_html
      return "" unless engine
      engine.placeholder_html || ""
    rescue *Onebox::Preview.web_exceptions
      ""
    end

    def options
      OpenStruct.new(@options)
    end

    def self.web_exceptions
     [Net::HTTPServerException, OpenURI::HTTPError, Timeout::Error, Net::HTTPError, Errno::ECONNREFUSED]
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
