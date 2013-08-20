module Onebox
  class Matcher
    def initialize(link)
      @url = link
    end

    def oneboxed
      case @url
      when /example\.com/ then Engine::ExampleOnebox
      when /amazon\.com/ then Engine::AmazonOnebox
      when /flickr\.com/ then Engine::FlickrOnebox
      when /qik\.com/ then Engine::QikOnebox
      when /stackexchange\.com/ then Engine::StackExchangeOnebox
      when /wikipedia\.com/ then Engine::WikipediaOnebox
      end
    end
  end
end
