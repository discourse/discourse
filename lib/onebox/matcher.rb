module Onebox
  class Matcher
    def initialize(link)
      @url = link
    end

    def oneboxed
      case @url
      when /example\.com/ then Engine::Example
      when /amazon\.com/ then Engine::Amazon
      end
    end
  end
end
