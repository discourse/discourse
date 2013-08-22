module Onebox
  class Preview
    attr_reader :cache

    def initialize(link, parameters = {})
      @url = link
      @options = parameters
      @cache = options.cache
      @engine = Matcher.new(@url).oneboxed
    end

    def to_s
      engine.to_html
    end

    def options
      OpenStruct.new(@options)
    end

    private

    def engine
      @engine.new(@url)
    end

    class InvalidURI < StandardError

    end
  end
end

