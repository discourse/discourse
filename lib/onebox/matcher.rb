module Onebox
  class Matcher
    def initialize(link)
      @url = link
    end

    def oneboxed
      uri = URI(@url)

      Engine.engines.select do |engine|
        engine === uri
      end.first
    rescue URI::InvalidURIError
      # If it's not a valid URL, don't even match
      nil
    end
  end
end
