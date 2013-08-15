module Onebox
  class Matcher
    def initialize(link)
      @url = link
    end

    def oneboxed
      case @url
      when /example\.com/ then Engine::Example
      when /amazon\.com/ then Engine::Amazon
      when /qik\.com/ then Engine::Qik
      when /stackexchange\.com/ then Engine::StackExchange
      when /wikipedia\.com/ then Engine::Wikipedia
      end
    end
  end
end
