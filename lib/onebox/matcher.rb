module Onebox
  class Matcher
    def initialize(link)
      @url = link
    end

    def ordered_engines
      @ordered_engines ||= Engine.engines.sort_by do |e|
        e.respond_to?(:priority) ? e.priority : 100
      end
    end

    def oneboxed
      uri = URI(@url)
      ordered_engines.find { |engine| engine === uri }
    rescue URI::InvalidURIError
      nil
    end
  end
end
