module Onebox
  class Preview
    def initialize(link, options = {})
      @url = link
      @engine = Matcher.new(@url).oneboxed
    end

    def to_s
      engine.to_html
    end

    private

    def engine
      @engine.new(@url)
    end

    class InvalidURI < StandardError

    end
  end
end

