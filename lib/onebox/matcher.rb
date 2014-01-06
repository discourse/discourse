module Onebox
  class Matcher
    def initialize(link)
      @url = link
    end

    def oneboxed
      URI(@url)

      Engine.engines.select do |engine|
        engine === @url
      end.first
    rescue URI::InvalidURIError
      # If it's not a valid URL, don't even match
    end
  end
end
