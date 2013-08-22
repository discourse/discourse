module Onebox
  class Matcher
    def initialize(link)
      @url = link
    end

    def oneboxed
      Engine.engines.select do |engine|
        engine === @url
      end.first
    end
  end
end
